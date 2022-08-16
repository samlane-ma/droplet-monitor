using Gtk;
using GLib;
using DOcean;

namespace DropletList {

class DropletList: Gtk.ListBox {
    private DODroplet[] droplets = {};
    private string token;
    private Gtk.Label placeholder;
    private Gtk.Image icon;
    private bool stay_running = true;

    // thread will do full update every 20 passes - the decay is how many times
    // it will do a full update every pass, in the case of a start/stop request
    private int decay = 1;

    private Mutex mutex = Mutex();

    // use Queues for the list of items to start/stop/reboot
    // then we can check if they get added multiple times and just run once
    private Queue<string> start_queue;
    private Queue<string> stop_queue;
    private Queue<string> reboot_queue;

    private string[] running = {};
    private bool is_selected = false;
    private string last_selected = "";
    private string last_ip = "";
    private Gtk.Label? ssh_label = null;

    public DropletList(string token) {
        this.token = token;
        start_queue = new Queue<string> ();
        stop_queue = new Queue<string> ();
        reboot_queue = new Queue<string> ();
        placeholder = new Gtk.Label("  Searching for droplets  \n\n\n");
        this.set_placeholder(placeholder);
        placeholder.show();
        this.row_selected.connect(update_selected);
        try {
            new Thread<void*>.try(null, get_all_droplets);
        } catch (Error thread_error) {
            message("Could not start thread");
        }
    }

    public void set_ssh_label(Gtk.Label label) {
        ssh_label = label;
    }

    private void update_selected(ListBoxRow? row) {
        if (row != null) {
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
        
    public void add_start () {
        if (is_empty()) return;
        if (is_selected) {
            start_queue.push_head(last_selected);
        }
    }

    public void add_stop () {
        if (is_empty()) return;
        if (is_selected) {
            stop_queue.push_head(last_selected);
        }
    }

    public void add_reboot () {
        if (is_empty()) return;
        if (is_selected) {
            reboot_queue.push_head(last_selected);
        }
    }

    public void quit_scan() {
        stay_running = false;
    }

    private void* get_all_droplets () {
        string old_check = "";
        string this_check = "";
        int cycle = 0;

        // since token is loaded async from keyring, add a slight delay 
        // before first cycle so token is loaded so it doesn't wait a cycle
        Thread.usleep(500000);
        
        while (stay_running) {

            // Check for stops
            string item = null;
            string[] stop_list = { };
	        while ((item = stop_queue.pop_head ()) != null) {
                if (!(item in stop_list)) {
                    stop_list += item;
                }
            }
            foreach (var selected_droplet in stop_list) {
		        toggle_selected(selected_droplet, DOcean.OFF);
            }

            // Check for starts
            item = null;
            string[] start_list = { };
	        while ((item = start_queue.pop_head ()) != null) {
		        if (!(item in stop_list)) {
                    start_list += item;
                }
            }
            foreach (var selected_droplet in start_list) {
		        toggle_selected(selected_droplet, DOcean.ON);
            }

            // Check for reboots
            item = null;
            string[] reboot_list = { };
	        while ((item = reboot_queue.pop_head ()) != null) {
		        if (!(item in reboot_list)) {
                    reboot_list += item;
                }
            }
            foreach (var selected_droplet in reboot_list) {
		        toggle_selected(selected_droplet, DOcean.REBOOT);
            }

            // Regular update
            if (cycle > 20 || decay > 0) {
                droplets = {};
                try{
                    droplets = DOcean.get_droplets(token);
                } catch (Error e) {
                    message ("Error: %s", e.message);
                }    
                this_check = "";
                
                // form a string from the results and if the next check forms
                // the same string, we know nothing has changed... 
                foreach (var droplet in droplets) {
                    this_check += @"$(droplet.name)_$(droplet.status)_$(droplet.public_ipv4)_";
                }
                if (old_check != this_check) {
                    Idle.add( () => {
                        return update_gui(droplets);
                    });
                    old_check = this_check;
                }
                cycle = 0;
                mutex.lock();
                decay = (decay >0 ? decay - 1: 0);
                mutex.unlock();
            } else {
                cycle++;
            }
            Thread.usleep(15000000);
        }
        return null;
    }

    public void set_update_icon(Gtk.Image icon) {
        this.icon = icon;
    }

    private bool is_empty() {
        return (this.get_children() == null);
    }

    public bool has_selected() {
        if (is_empty()) return false;
        if (this.get_selected_row() == null) return false;
        if (this.get_selected_row().get_index() >= 0) {
            return true;
        }
        return false;
    }

    public void update() {
        mutex.lock();
        decay = 4;
        mutex.unlock();
    }

    public void update_token(string new_token) {
        this.token = new_token;
        update();
    }

    private bool update_gui (DODroplet[] droplet_list) {
        // Must be done from Idle so we don't crash the panel

        if (!stay_running) {
            // if the app is removed before the callback (rare but possible)
            // lets bail on the update
            return false;
        }

        int current_selected = -1;
        string selected;
        bool all_active = true;
        bool empty = false;
        running = {};

        if (is_empty()) {
            this.unselect_all();
            empty = true;
        } else {
            if (this.get_selected_row() == null) {
                current_selected = -1;
            } else {
                current_selected = this.get_selected_row().get_index();
            }
        }
        if (current_selected >= 0 && !empty && droplet_list.length > 0) {
            selected = droplet_list[this.get_selected_row().get_index()].name;
        } else {
            this.unselect_all();
            selected = "";
        }

        this.foreach ((element) => this.remove (element));
        int found_count = 0;
        foreach (var droplet in droplet_list) {
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
            if (selected == droplet.name && !empty) {
                this.select_row(this.get_row_at_index(found_count));
            }
            found_count++;
        }
        if (found_count == 0) {
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
        return (last_selected in running);
    }

    public void toggle_selected (string selected_droplet, int method) {
        if (is_empty()) return;
        int current_selected = this.get_selected_row().get_index();
        if (current_selected >= 0) {
            try {
                DOcean.power_droplet(token, selected_droplet, method);
            } catch (Error e) {
                message("Error accessing server: %s", e.message);
            }
            mutex.lock();
            decay = 3;
            mutex.unlock();
        }
    
    }

} // end class

} // end namespace