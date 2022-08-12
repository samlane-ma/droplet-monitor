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
    private int decay = 1;
    private Mutex mutex = Mutex();
    private Queue<string> start_queue;
    private Queue<string> stop_queue;

    public DropletList(string token) {
        this.token = token;
        start_queue = new Queue<string> ();
        stop_queue = new Queue<string> ();
        placeholder = new Gtk.Label("  Searching for droplets  \n\n\n");
        this.set_placeholder(placeholder);
        placeholder.show();
        try {
            var thread = new Thread<void*>.try(null, get_all_droplets);
        } catch (Error thread_error) {
            message("Could not start thread");
        }
    }

    public void add_start () {
        if (is_empty()) return;
        int current_selected = this.get_selected_row().get_index();
        if (current_selected >= 0) {
            start_queue.push_head(droplets[current_selected].id);
        }
    }

    public void add_stop () {
        if (is_empty()) return;
        int current_selected = this.get_selected_row().get_index();
        if (current_selected >= 0) {
            stop_queue.push_head(droplets[current_selected].id);
        }
    }

    private void* get_all_droplets () {
        string old_check = "";
        string this_check = "";
        int cycle = 0;
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

            // Regular update
            if (cycle > 20 || decay > 0) {
                droplets = {};
                try{
                    droplets = DOcean.get_droplets(token);
                } catch (Error e) {
                    message ("Error: %s", e.message);
                }    
                this_check = "";
                foreach (var droplet in droplets) {
                    this_check += @"$(droplet.name)_$(droplet.status)_$(droplet.ipv4[0])_";
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
        if (this.get_selected_row().get_index() >= 0) {
            return true;
        }
        return false;
    }

    public bool is_selected_running() {
        if ( is_empty()) return false;
        int current_selected = this.get_selected_row().get_index();
        if (has_selected()) {
            return (droplets[current_selected].status == "active");
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

        // Mostly prevents index error crashes and GLib asserion errors
        // but needs cleanup and simplification

        int current_selected = -1;
        string selected;
        bool all_active = true;
        bool empty = false;

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
        if (current_selected >= 0 && !empty) {
            selected = droplet_list[this.get_selected_row().get_index()].name;
        } else {
            this.unselect_all();
            selected = "";
        }

        this.foreach ((element) => this.remove (element));
        int found_count = 0;
        foreach (var droplet in droplet_list) {
            var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 20);
            var label = new Gtk.Label(droplet.name);
            Gtk.Image status_image = new Gtk.Image();
            if (droplet.status == "active") {
                status_image.set_from_icon_name("emblem-checked", Gtk.IconSize.LARGE_TOOLBAR);
            } else {
                status_image.set_from_icon_name("emblem-error", Gtk.IconSize.LARGE_TOOLBAR);
                all_active = false;
            }
            hbox.pack_start(status_image, false, false, 5);
            hbox.pack_start(label, false, false, 5);
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