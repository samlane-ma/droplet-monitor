using Gtk;
using GLib;
using DOcean;

namespace DropletList {

class DropletList: Gtk.ListBox {
    private DODroplet[] droplets = {};
    private string token;
    private Gtk.Label placeholder;
    private Gtk.Image icon;

    public DropletList(string token) {
        this.token = token;
        placeholder = new Gtk.Label("  Searching for droplets  \n\n\n");
        this.set_placeholder(placeholder);
        placeholder.show();
        update();
        Timeout.add_seconds_full(GLib.Priority.DEFAULT, 300, () => {
            update();
            return true;
        });
    }

    public void set_update_icon(Gtk.Image icon) {
        this.icon = icon;
    }

    private async void get_droplet_list ()
    {
        new Thread<void*> (null, () => {
            try {
                this.droplets = DOcean.get_droplets(token);
            } catch (Error e) {
                this.droplets = {};
                this.unselect_all();
            }
            Idle.add (get_droplet_list.callback);
            return null;
        });
        yield;
    }

    public void update() {
        get_droplet_list.begin ((obj, res) => {
            get_droplet_list.end (res);
            this.update_gui();
        });
    }

    public bool has_selected() {
        if (this.get_children() == null) {
            return false;
        }
        if (this.get_selected_row().get_index() >= 0) {
            return true;
        }
        return false;
    }

    public bool is_selected_running() {
        if (this.get_children() == null) {
            return false;
        }
        int index = this.get_selected_row().get_index();
        if (has_selected()) {
            return (droplets[index].status == "active");
        }
        return false;
    }

    public void update_token(string new_token) {
        this.token = new_token;
        update();
    }

    private bool update_gui () {
        int index = -1;
        string selected;
        bool all_active = true;
        bool empty = false;
        if (this.get_children() == null) {
            this.unselect_all();
            empty = true;
        } else {
            index = this.get_selected_row().get_index();
        }
        if (index >= 0 && !empty) {
            selected = droplets[this.get_selected_row().get_index()].name;
        } else {
            this.unselect_all();
            selected = "";
        }
        this.foreach ((element) => this.remove (element));
        int i = 0;
        foreach (var droplet in droplets) {
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
                this.select_row(this.get_row_at_index(i));
            }
            i++;
        }
        if (i == 0) {
            icon.set_from_icon_name("do-server-error-symbolic", Gtk.IconSize.MENU);
        } else if (all_active) {
            icon.set_from_icon_name("do-server-ok-symbolic", Gtk.IconSize.MENU);
        } else {
            icon.set_from_icon_name("do-server-warn-symbolic", Gtk.IconSize.MENU);       
        } 
        this.show_all();
        return false;
    }

    public void shutdown_selected () {
        if (this.get_children() == null) {
            return;
        }
        int index = this.get_selected_row().get_index();
        if (index >= 0) {
            try {
                DOcean.power_droplet(token,droplets[index], DOcean.OFF);
            } catch (Error e) {
                message("Cannot stop server: %s", e.message);
            }
            Timeout.add_seconds_full(GLib.Priority.DEFAULT, 20, () => {
                update();
                return true;
            });
        }
    }

    public void startup_selected () {
        if (this.get_children() == null) {
            return;
        }
        int index = this.get_selected_row().get_index();
        if (index >= 0) {
            try {
                DOcean.power_droplet(token,droplets[index], DOcean.ON);
            } catch (Error e) {
                message("Cannot start server: %s", e.message);
            }
            Timeout.add_seconds_full(GLib.Priority.DEFAULT, 20, () => {
                update();
                return true;
            });
        }
    }

} // end class

} // end namespace 