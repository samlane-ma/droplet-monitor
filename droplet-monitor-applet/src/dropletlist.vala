using Gtk;
using GLib;

namespace DropletApplet {

public class DropletList: Gtk.ListBox {
    private DOClient client = null;
    private DODroplet[] droplets = {};
    private string token;
    private bool stay_running = true;
    private string[] running = {};
    private string old_check = "";
    private bool sort_by_status = true;
    private bool sort_offline_first = true;
    private bool sort_ascending = true;

    /* We update these every time the row_selected signal is emitted.
     * It is easier (and safer) to get these values later on from here than it
     * is to get the index of the selected row and then check the droplet_list
     */
    private bool selection_made = false;
    private string selected_droplet = "";
    private string selected_ip = "";

    /* This will signal the widget or applet with the necessary information to
     * set the proper widget / panel icon, or determine sizes of GUI elements
     */
    public signal void update_count(int count, bool all_active);

    public DropletList(string do_token) {
        this.token = do_token;
        try {
            client = Bus.get_proxy_sync (BusType.SESSION, "com.github.samlane_ma.droplet_monitor",
                                                          "/com/github/samlane_ma/droplet_monitor");
        } catch (Error e) {
            warning("Unable to get bus");
        }

        client.droplets_updated.connect(() => {
            get_all_droplets();
        });

        var placeholder = new Gtk.Label("  Searching for droplets  \n\n\n");
        this.set_placeholder(placeholder);
        placeholder.show();
        this.row_selected.connect(update_selected);

        update_token(token);

        Timeout.add_seconds(60, get_all_droplets);

        /* Service will signal if its running without a token. This would
         * most likely only happen if the server is killed and restarted
         * while the applet is already running. No need to re-update the list
         * after passing it this token, as the server will trigger an update
         */
        client.no_token.connect(() => {
            update_token(token);
        });

        /* If the applet and widget are running at the same time, and the
         * other updates the token, we can listen for this change on this
         * one to make sure the tokens stay in sync between both. A rare
         * instance, but if the
         */
        client.token_updated.connect((newtoken) => {
            this.token = newtoken;
        });
        this.set_sort_func(sort_droplets);
    }

    /* This handles updating the droplet list currrent selected data */
    private void update_selected(ListBoxRow? row) {
        if (row != null) {
            var box = (Gtk.Box) row.get_child();
            var widgets = box.get_children();
            var label2 = (Gtk.Label) widgets.nth_data(2);
            var ip_address = label2.get_label();
            string id = "";
            foreach (var droplet in droplets) {
                if (droplet.public_ipv4 == ip_address) {
                    id = droplet.id;
                }
            }
            if (id != "") {
                selected_ip = ip_address;
                selected_droplet = id;
                selection_made = true;
                return;
            }
        }
        selected_ip = "";
        selected_droplet = "";
        selection_made = false;
    }

    public void do_action (int action) {
        if (is_empty()) return;
        if (selection_made && selected_droplet != "") {
            toggle_selected(selected_droplet, action);
        }
    }

    public void quit_scan() {
        // stop thread when applet is removed
        stay_running = false;
    }

    public void change_sort(bool ascending, bool by_status, bool offline_first=true) {
        sort_by_status = by_status;
        sort_offline_first = offline_first;
        sort_ascending = ascending;
        update();
    }

    private int sort_droplets(ListBoxRow r1, ListBoxRow r2) {
        // If sort by status is enabled, sort that way first, then by name
        int[] online= {};
        string[] name = {};
        ListBoxRow[] row = {r1, r2};
        for (int i = 0; i < 2; i++) {
            var box = (Gtk.Box) row[i].get_child();
            var widgets = box.get_children();
            var icon = (Gtk.Image) widgets.nth_data(0);
            var label = (Gtk.Label) widgets.nth_data(1);
            string icon_name;
            IconSize icon_size;
            icon.get_icon_name(out icon_name, out icon_size);
            int is_on = (int) icon_name.contains("online");
            string this_name = label.get_label().up();
            online += is_on;
            name += this_name;
        }
        if (online[0] != online[1] && sort_by_status) {
            return sort_offline_first ? (online[0] - online[1]) : (online[1] - online[0]);
        } else {
            return sort_ascending ? strcmp(name[0], name[1]) : 0;
        }
    }

    private int highlight_row(string ip) {
        int i = 0;
        foreach (Gtk.Widget child in this.get_children()) {
            ListBoxRow row = (ListBoxRow) child;
            var box = (Gtk.Box) row.get_child();
            var widgets = box.get_children();
            var ip_addr = (Gtk.Label) widgets.nth_data(2);
            string check_address = ip_addr.get_label();
            if (check_address == ip) {
                return i;
            }
            i++;
        }
        return -1;
    }

    private bool get_all_droplets () {

        string this_check = "";  // current GET request
        droplets = {};

        client.get_droplets.begin((obj, res) => {
            try {
                var droplet_check = client.get_droplets.end(res);
                droplets = droplet_check;
                foreach (var droplet in droplets) {
                    /* We are forming a string based on the current check. If the current check
                     * matches the last one, we know nothing significant has changed and therefore
                     * we don't need to waste time recreating all the GUI list elements
                     */
                    this_check += @"$(droplet.name)_$(droplet.status)_$(droplet.public_ipv4)_";
                }
                if (old_check != this_check) {
                    update_gui(droplets);
                    old_check = this_check;
                }
            } catch (Error e) {
                // Something went wrong, we need to clear the list
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
        return selection_made;
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

        var saved_droplet = selected_ip;

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
            var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 20);
            var name_label = new Gtk.Label(droplet.name);
            var ip_label = new Gtk.Label(droplet.public_ipv4);
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
            hbox.pack_start(name_label, false, false, 5);
            hbox.pack_end(ip_label, false, false, 5);
            this.insert(hbox, -1);
            if (selected_droplet == droplet.id) {
                this.select_row(this.get_row_at_index(found_count));
            }
            found_count++;
        }
        if (found_count == 0) {
            selected_droplet = "";
            selected_ip = "";
        } else {
            int hl_row = highlight_row(saved_droplet);
            if (hl_row >= 0) {
                this.select_row(this.get_row_at_index(hl_row));
            }
        }
        update_count(found_count, all_active);
        this.show_all();
        return false;
    }

    public string get_selected_ip () {
        return selected_ip;
    }

    public bool selected_is_running() {
        // checks if selection is running so we don't send unneeded signals
        return (selected_droplet in running);
    }

    /* This is responsible for actually sending the droplet id and the action
     * to be performed to the service. Mode can be ON, OFF, or REBOOT
     */
    private void toggle_selected (string selected_droplet, int mode) {
        // sends the action to the selected droplet
        client.send_droplet_signal.begin(mode, selected_droplet, (obj, res) => {
            try {
                client.send_droplet_signal.end(res);
            } catch (Error e) {
                message("Unable to send signal");
            }
        });
    }

    public void update() {
        old_check = "";
        get_all_droplets();
    }

} // end class

} // end namespace
