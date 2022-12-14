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
    private int decay = 3;

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
            mutex.lock();
            // if thread clears / reduces droplet list count, we need to make
            // sure we don't crash by selecting an index that no longer exists
            if (droplets.length < (row.get_index()+1)) { 
                mutex.unlock();
                return; }
            last_selected = droplets[row.get_index()].id;
            last_ip = droplets[row.get_index()].public_ipv4;
            mutex.unlock();
            is_selected = true;
            ssh_label.set_label(last_ip);
        }
        else {
            ssh_label.set_label("");
            is_selected = false;
        }
    }

    // these allow parent class to add actions
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
        // stop thread when applet is removed
        stay_running = false;
    }

    private void* get_all_droplets () {
        
        string old_check = "";   // data returned from previous GET
        string this_check = "";  // current GET request
        int cycle = 0;           // current pass

        /*
        Thread will
          1: process stops added to the queues
          2: process starts added to the queue
          3: process reboots added to the queue
          4: do a full check if its been 15 cycles or if decay has been added
             to check more frequently after a change (start, stop,reboot)

         One cycle is approx. 18 seconds.
         A full check happens roughly every 4.5 minutes.
        */

        // Since token is loaded async from keyring, add a slight delay 
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

            if (stop_list.length + start_list.length + reboot_list.length > 0) {
                decay = 4;
            }

            // Regular update if correct cycle or if extra checks needed
            if (cycle > 15 || decay > 0) {
                droplets = {};
                try{
                    // request updated droplet list from D.O.
                    var droplet_check = DOcean.get_droplets(token);
                    mutex.lock();
                    droplets = droplet_check;
                    mutex.unlock();
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
        // sets the applet panel icon
        this.icon = icon;
    }

    private bool is_empty() {
        // returns true if this ListBox is empty
        return (this.get_children() == null);
    }

    public bool has_selected() {
        // returns true if this ListBox has a selected row
        if (is_empty()) return false;
        if (this.get_selected_row() == null) return false;
        if (this.get_selected_row().get_index() >= 0) {
            return true;
        }
        return false;
    }

    public void update() {
        // allows parent class to trigger extra updates for 4 loops, in case of
        // an event such as Refresh button pressed or network changed
        mutex.lock();
        decay = 4;
        mutex.unlock();
    }

    public void update_token(string new_token) {
        // allows parent class to update the D.O. oauth token
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

    public void toggle_selected (string selected_droplet, int method) {
        // sends the action to the selected droplet
        if (is_empty()) return;
        int current_selected = this.get_selected_row().get_index();
        if (current_selected >= 0) {
            try {
                DOcean.power_droplet(token, selected_droplet, method);
            } catch (Error e) {
                message("Error accessing server: %s", e.message);
            }
        }
    }

} // end class

} // end namespace