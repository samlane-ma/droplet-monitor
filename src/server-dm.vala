[DBus (name = "com.github.samlane_ma.droplet_monitor")]
public class DOServer : Object {

    private string last = "";
    private string current = "";
    private string token = "";
    DODroplet[] all_droplets = {};
    private Soup.Session session = new Soup.Session();

    public DOServer() {
        Timeout.add_seconds_full(GLib.Priority.DEFAULT, 10, () => {
            if (token == "") {
                return true;
            }
            current = get_droplet_list(session, token);
            if (current != last) {
                last = current;
                all_droplets = get_droplet_data(current);
                droplets_updated();
            }
            return true;
        });
        Idle.add(() => {
            no_token();
            return false;
        });
    }

    private void update () {
        current = get_droplet_list(session, token);
        all_droplets = get_droplet_data(current);
        if (current != last) {
            last = current;
            droplets_updated();
        }
    }

    [DBus (name = "GetDroplets")]
    public DODroplet[] get_droplets () throws DBusError, IOError {
        return all_droplets;
    }

    [DBus (name = "GetCurrentDroplets")]
    public string get_current_droplets() throws DBusError, IOError {
        string drops = "\n";
        foreach(DODroplet d in all_droplets) {
            drops += @"$(d.name) : $(d.public_ipv4) : $(d.status)\n";
        }
        return drops;
    }

    [DBus (name = "SetToken")]
    public void set_token (string token) throws DBusError, IOError {
        this.token = token;
        update();
    }

    [DBus (name = "DropletsUpdated")]
    public signal void droplets_updated ();

    [DBus (name = "NoToken")]
    public signal void no_token ();
}

void on_bus_aquired (DBusConnection conn) {
    try {
        conn.register_object ("/com/github/samlane_ma/droplet_monitor", new DOServer ());
    } catch (IOError e) {
        stderr.printf ("Could not register service\n");
    }
}

string get_droplet_list (Soup.Session session, string token) {
    string output = "";
    var message = new Soup.Message ("GET", "https://api.digitalocean.com/v2/droplets");
    message.request_headers.append ("Authorization", @"Bearer $token");
    try {
        var retbytes = session.send_and_read (message);
        output = (string)retbytes.get_data();
    } catch (Error e) {
        return "no data";
    }
    return output;
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


void main () {
    MainLoop mainloop = new MainLoop();
    Bus.own_name (BusType.SESSION, "com.github.samlane_ma.droplet_monitor", BusNameOwnerFlags.NONE,
                  on_bus_aquired,
                  () => {},
                  () => { stderr.printf ("Could not aquire name\n");
                          mainloop.quit(); });

    mainloop.run();
}