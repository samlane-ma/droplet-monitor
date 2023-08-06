/*
 * This file is part of the Budgie Droplet Monitor applet
 *
 * Copyright Samuel Lane
 * Website=https://github.com/samlane-ma/droplet-monitor
 *
 * This program is free software: you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version
 * 3 of the License, or (at your option) any later version.
 */

[DBus (name = "com.github.samlane_ma.droplet_monitor")]
public class DOServer : Object {

    const int OFF = 0;
    const int ON = 1;
    const int REBOOT = 2;

    // If the Dbus server has not heard anything in TIMEOUT_SECONDS, exit.
    const int TIMEOUT_SECONDS = 600;

    private string last = "";
    private string token = "";
    DODroplet[] all_droplets = {};
    private bool empty_once = false;
    private Soup.Session session;
    private uint64 last_time = 0;

    public DOServer() {

        session = new Soup.Session();
        session.timeout = 6;
        last_time = GLib.get_real_time();

        Timeout.add_seconds_full(GLib.Priority.DEFAULT, 15, () => {
            int difference =  (int) (GLib.get_real_time() - last_time) / 1000000;
            // We will quit the service if we have not heard from the applet or widget for 1 min
            if (difference > TIMEOUT_SECONDS ) {
                mainloop.quit();
            }
            string current = "no data";
            if (token == "") {
                return true;
            }
            current = get_droplet_list();
            if (current != last) {
                if (current == "no data" && !empty_once) {
                    // Don't clear the list unless we get two empty results in a row
                    // Prevents the droplets from clearing due to a one time connection error
                    empty_once = true;
                    return true;
                }
                last = current;
                all_droplets = get_droplet_data(current);
                droplets_updated();
            }
            empty_once = false;
            return true;
        });
        Idle.add(() => {
            no_token();
            return false;
        });
    }

    private void update () {
        var current = get_droplet_list();
        all_droplets = get_droplet_data(current);
        if (current != last) {
            last = current;
            droplets_updated();
        }
    }

    private string get_droplet_list () {
        string output = "no data";
        var message = new Soup.Message ("GET", "https://api.digitalocean.com/v2/droplets");
        message.request_headers.append ("Authorization", @"Bearer $token");
        message.add_flags(Soup.MessageFlags .NO_REDIRECT);
        try {
            var retbytes = session.send_and_read (message);
            output = (string)retbytes.get_data();
        } catch (Error e) {
            return "no data";
        }
        return output;
    }

    [DBus (name = "GetDroplets")]
    public async DODroplet[] get_droplets () throws DBusError, IOError {
        last_time = GLib.get_real_time();
        return all_droplets;
    }


    [DBus (name = "SendDropletSignal")]
    public async string send_droplet_signal(int mode, string droplet_id) throws DBusError, IOError {
        last_time = GLib.get_real_time();
        if (token == "") {
            return "no token";
        }
        string mparams = "";
        if (mode == ON) {
            mparams = "{\"type\":\"power_on\"}";
        } else if (mode == OFF) {
            mparams = "{\"type\":\"shutdown\"}";
        } else if (mode == REBOOT) {
            mparams = "{\"type\":\"reboot\"}";
        } else {
            return "invalid type";
        }

        var message = new Soup.Message ("POST", @"https://api.digitalocean.com/v2/droplets/$droplet_id/actions");
        message.set_request_body_from_bytes("application/json", new Bytes(mparams.data));
        message.request_headers.append("Content-Type","application/json");
        message.request_headers.append ("Authorization", @"Bearer $token");
        message.add_flags(Soup.MessageFlags .NO_REDIRECT);
        try {
            var response = session.send_and_read(message);
            return (string)response.get_data();
        } catch (Error e) {
            return "Error sending signal";
        }
    }

    [DBus (name = "SetToken")]
    public async void set_token (string token) throws DBusError, IOError {
        last_time = GLib.get_real_time();
        this.token = token;
        token_updated(token);
        update();
    }

    [DBus (name = "DropletsUpdated")]
    public signal void droplets_updated ();

    [DBus (name = "NoToken")]
    public signal void no_token ();

    /* Since the applet and widget use the same token, this simply lets one know if
     * the other changes the token. Only would matter if for some reason the service
     * was restarted after updating the token but before a restart of the panel. However,
     * still best to keep these two in sync.
     */
    [DBus (name = "TokenUpdated")]
    public signal void token_updated (string token);
}

void on_bus_aquired (DBusConnection conn) {
    try {
        conn.register_object ("/com/github/samlane_ma/droplet_monitor", new DOServer ());
    } catch (IOError e) {
        stderr.printf ("Could not register service\n");
    }
}

public struct DODroplet {
    public string name;
    public string location;
    public string status;
    public string public_ipv4;
    public string public_ipv6;
    public string private_ipv4;
    //public string private_ipv6;
    public string floating_ip;
    public string id;
    public string image_name;
    public string image_distribution;
    public string image_description;
    public string image_created;
    public string size_vcpus;
    public string size_storage;
    public string size_memory;
    //public string size_slug;
    public string size_price_monthly;
}

DODroplet[] get_droplet_data (string result) {

    // TO DO - Check result to see if it is error message.
    // If so, bail early and skip all this.

    DODroplet[] droplet_list = {};
    Json.Array? response = null;

    var parser = new Json.Parser ();
    try {
        parser.load_from_data (result, -1);
        var root = parser.get_root ();
        if (root == null) {
            return droplet_list;
        }
        var root_object = root.get_object ();
        if (!root_object.has_member("droplets")) {
            return droplet_list;
        }
        response = root_object.get_array_member ("droplets");
        if (response == null) {
            return droplet_list;
        }
    } catch (Error e) {
        return droplet_list;
    }

    foreach (var droplet in response.get_elements ()) {
        string ipv4 = "N/A";
        string ipv6 = "N/A";
        string priv_ipv4 = "N/A";
        string priv_ipv6 = "N/A";
        string drop_floating_ip = "N/A";
        string[] all_ips = {};

        var drop = droplet.get_object ();

        var networks = drop.get_member("networks").get_object();
        var ip4list = networks.get_array_member("v4");
        var ip6list = networks.get_array_member("v6");

        var regioninfo = drop.get_member("region").get_object();
        var imageinfo = drop.get_member("image").get_object();
        var sizeinfo = drop.get_member("size").get_object();

        foreach (var ip in ip4list.get_elements()) {
            if (ip.get_object().get_string_member("type") == "public") {
                string ipaddr = ip.get_object().get_string_member("ip_address");
                if (ipaddr in all_ips) {
                    drop_floating_ip = ipaddr;
                } else {
                    all_ips += ipaddr;
                }
            } else {
                priv_ipv4 = ip.get_object().get_string_member("ip_address");
            }
        };
        foreach (string ip in all_ips) {
            if (ip != drop_floating_ip) {
                ipv4 = ip;
            }
        }

        foreach (var ip in ip6list.get_elements()) {
            if (ip.get_object().get_string_member("type") == "public") {
                ipv6 = ip.get_object().get_string_member("ip_address");
            } else {
                priv_ipv6 = ip.get_object().get_string_member("ip_address");
            }
        };

        DODroplet found_droplet = DODroplet() {
            name = drop.get_string_member ("name"),
            id = drop.get_int_member("id").to_string(),
            public_ipv4 = ipv4,
            public_ipv6 = ipv6,
            private_ipv4 = priv_ipv4,
            //private_ipv6 = priv_ipv6,
            floating_ip = drop_floating_ip,
            status = drop.get_string_member("status"),
            location = regioninfo.get_string_member("name"),
            image_name = imageinfo.get_string_member("name"),
            image_created = imageinfo.get_string_member("created_at"),
            image_distribution = imageinfo.get_string_member("distribution"),
            image_description = imageinfo.get_string_member("description"),
            size_vcpus = sizeinfo.get_int_member("vcpus").to_string(),
            size_storage = sizeinfo.get_int_member("disk").to_string(),
            size_memory = sizeinfo.get_int_member("memory").to_string(),
            //size_slug = sizeinfo.get_string_member("slug"),
            size_price_monthly = sizeinfo.get_int_member("price_monthly").to_string()
        };

        droplet_list += found_droplet;
    }

    return droplet_list;
}

MainLoop mainloop;

void main () {
    mainloop = new MainLoop();
    Bus.own_name (BusType.SESSION, "com.github.samlane_ma.droplet_monitor", BusNameOwnerFlags.NONE,
                  on_bus_aquired,
                  () => {},
                  () => { stderr.printf ("Could not aquire name\n");
                          mainloop.quit(); });

    mainloop.run();
}
