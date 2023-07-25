using Gtk;
using GLib;
using WidgetDOcean;

namespace WidgetDropletList {

[DBus (name = "com.github.samlane_ma.droplet_monitor")]
interface DOClient : GLib.Object {
    public abstract async DODroplet[] get_droplets () throws GLib.Error;
    public abstract async void set_token(string token) throws GLib.Error;
    public abstract async string send_droplet_signal(int mode, string droplet_id) throws GLib.Error;
    public signal void droplets_updated ();
    public signal void no_token ();
}

class WidgetDropletList: Gtk.ListBox {
    private DODroplet[] droplets = {};
    private string token;
    private Gtk.Label placeholder;
    private Gtk.Image icon;
    private bool stay_running = true;

    private string[] running = {};
    private bool is_selected = false;
    private string last_selected = "";
    private string last_ip = "";
    public Gtk.Label? ssh_label = null;
    private DOClient client = null;
    private string old_check = "";


    public WidgetDropletList(string do_token, Gtk.Image status_icon, Gtk.Label label_ssh) {

        this.icon = status_icon;
        this.ssh_label = label_ssh;

        try {
            client = Bus.get_proxy_sync (BusType.SESSION, "com.github.samlane_ma.droplet_monitor",
                                                          "/com/github/samlane_ma/droplet_monitor");
        } catch (Error e) {

        }

        client.droplets_updated.connect(() => {
            get_all_droplets();
        });

        this.token = do_token;

        placeholder = new Gtk.Label("  Searching for droplets  \n\n\n");
        this.set_placeholder(placeholder);
        placeholder.show();
        this.row_selected.connect(update_selected);

        update_token(token);

        Timeout.add_seconds(5, get_all_droplets);

        /* Service will signal if its running without a token. This would
         * most likely only happen if the server is killed and restarted
         * while the applet is already running. No need to re-update the list
         * after passing it this token, as the server will trigger an update
         */
        client.no_token.connect(() => {
            update_token(token);
        });
    }

    private void update_selected(ListBoxRow? row) {
        if (row != null) {
            if (droplets.length < (row.get_index()+1)) {
                return;
            }
            last_selected = droplets[row.get_index()].id;
            last_ip = droplets[row.get_index()].public_ipv4;
            is_selected = true;
            ssh_label.set_label(last_ip);
        }
        else {
            ssh_label.set_label("");
            is_selected = false;
        }
    }

    // these allow parent class to add actions
    public void do_action (int action) {
        if (is_empty()) return;
        if (is_selected) {
            toggle_selected(last_selected, action);
        }
    }

    public void quit_scan() {
        // stop thread when applet is removed
        stay_running = false;
    }

    private bool get_all_droplets () {

        string this_check = "";  // current GET request

        // Regular update if correct cycle or if extra checks needed
        droplets = {};

        client.get_droplets.begin((obj, res) => {
            try {
                var droplet_check = client.get_droplets.end(res);
                droplets = droplet_check;
                foreach (var droplet in droplets) {
                    this_check += @"$(droplet.name)_$(droplet.status)_$(droplet.public_ipv4)_";
                }
                if (old_check != this_check) {
                    update_gui(droplets);
                    old_check = this_check;
                }
            } catch (Error e) {
                update_gui(droplets);
                old_check = "";
            }
        });
        return stay_running;
    }

    private bool is_empty() {
        // returns true if this ListBox is empty
        return (this.get_children() == null);
    }

    public bool has_selected() {
        // returns true if this ListBox has a selected row
        if (is_empty()) return false;
        if (this.get_selected_row() == null) {
            return false;
        }
        if (this.get_selected_row().get_index() >= 0) {
            return true;
        }
        return false;
    }

    public void update_token(string new_token) {
        // allows parent class to update the D.O. oauth token
        this.token = new_token;

        client.set_token.begin(token, (obj, res) => {
            try {
                client.set_token.end(res);
            } catch (Error e) {
                message("Unable to set token");
            }
        });
    }

    private bool update_gui (DODroplet[] droplet_list) {
        // Must be done from Idle so we don't crash the panel

        if (!stay_running) {
            // if the app is removed before the callback (rare but possible)
            // lets bail on the update
            return false;
        }

        bool all_active = true;
        running = {};

        this.foreach ((element) => this.remove (element));
        int found_count = 0;
        foreach (var droplet in droplet_list) {
            // forms the ListBox
            var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);
            hbox.set_size_request(-1, 20);
            var name_label = new Gtk.Label(droplet.name);
            var ip_label = new Gtk.Label(droplet.public_ipv4);
            ip_label.set_width_chars(15);
            ip_label.set_alignment(0.0f, 0.5f);
            string ip_tooltip = @"Private: $(droplet.private_ipv4)\nPublic: $(droplet.public_ipv4)\nFloating:" +
                                @" $(droplet.floating_ip)\nIPv6: $(droplet.public_ipv6)";
            ip_label.set_tooltip_text(ip_tooltip);
            string info_tooltip = @"ID: $(droplet.id)\nLocation: $(droplet.location)\nImage name:"+
                                  @" $(droplet.image_name)\nDistribution: $(droplet.image_distribution)\n" +
                                  @"Description: $(droplet.image_description)\nCreated: $(droplet.image_created)";
            name_label.set_tooltip_text(info_tooltip);
            string status_tooltip = @"vCPUs: $(droplet.size_vcpus)\nStorage: $(droplet.size_storage)GB\n" +
                                    @"Memory: $(droplet.size_memory)GB\nMonthly: $$" + @"$(droplet.size_price_monthly)";
            Gtk.Image status_image = new Gtk.Image();
            status_image.set_tooltip_text(status_tooltip);
            if (droplet.status == "active") {
                running += droplet.id;
                status_image.set_from_icon_name("do-server-online", Gtk.IconSize.MENU);
            } else {
                status_image.set_from_icon_name("do-server-offline", Gtk.IconSize.MENU);
                all_active = false;
            }
            hbox.pack_start(status_image, false, false, 5);
            hbox.pack_start(ip_label, false, false, 0);
            hbox.pack_start(name_label, false, false, 0);
            this.insert(hbox, -1);
            if (last_selected == droplet.id) {
                this.select_row(this.get_row_at_index(found_count));
            }
            found_count++;
        }

        // choose the correct panel icon
        if (found_count == 0) {
            last_selected = "";
            icon.set_from_icon_name("do-server-error-symbolic", Gtk.IconSize.MENU);
        } else if (all_active) {
            icon.set_from_icon_name("do-server-ok-symbolic", Gtk.IconSize.MENU);
        } else {
            icon.set_from_icon_name("do-server-warn-symbolic", Gtk.IconSize.MENU);
        }
        this.show_all();
        return false;
    }

    public string get_selected_ip () {
        foreach (var droplet in droplets) {
            if (droplet.id == last_selected) {
                return droplet.public_ipv4;
            }
        }
        return "";
    }

    public bool selected_is_running() {
        // checks if selection is running so we don't send unneeded signals
        return (last_selected in running);
    }

    public void toggle_selected (string selected_droplet, int mode) {
        // sends the action to the selected droplet
        if (is_empty()) return;
        int current_selected = this.get_selected_row().get_index();
        if (current_selected >= 0) {
            client.send_droplet_signal.begin(mode, selected_droplet, (obj, res) => {
                try {
                    client.send_droplet_signal.end(res);
                } catch (Error e) {
                    message("Unable to send signal");
                }
            });
        }
    }

    public void update() {
        get_all_droplets();
    }

} // end class

} // end namespace