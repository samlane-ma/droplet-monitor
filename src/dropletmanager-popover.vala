using Gtk;
using DropletList;

namespace DropletPopover {

    public class DropletPopover : Budgie.Popover {

        private DropletList.DropletList droplet_list;

        public DropletPopover(Gtk.EventBox relative_parent, string token) {
            Object(relative_to: relative_parent);

            droplet_list = new DropletList.DropletList(token);
            Gtk.Grid grid = new Gtk.Grid();
            grid.set_column_homogeneous(true);
            grid.set_column_spacing(10);

            droplet_list.set_update_icon((Gtk.Image) relative_parent.get_child());
            Gtk.ToggleButton button_lock = new Gtk.ToggleButton();
            button_lock.set_label("Actions");
            Gtk.Button button_refresh = new Gtk.Button();
            button_refresh.set_label("Refresh");
            Gtk.Button button_start = new Gtk.Button();
            button_start.set_label("Start");
            Gtk.Button button_stop = new Gtk.Button();
            button_stop.set_label("Stop");
            Gtk.Button button_copy = new Gtk.Button();
            button_copy.set_label("Copy IP");
            Gtk.Button button_reboot = new Gtk.Button();
            button_reboot.set_label("Reboot");
            Gtk.Label label_spacer = new Gtk.Label("");
            label_spacer.set_width_chars(50);
            Gtk.Label label_status = new Gtk.Label(" ");
            grid.attach(label_spacer,0,0,3,1);
            grid.attach(new Gtk.Separator(Gtk.Orientation.HORIZONTAL),0,1,3,1);
            grid.attach(droplet_list,0,2,3,1);
            grid.attach(label_status,0,3,3,1);
            grid.attach(new Gtk.Separator(Gtk.Orientation.HORIZONTAL),0,4,3,1);
            grid.attach(button_lock,0,5,1,1);
            grid.attach(button_refresh,1,5,1,1);
            grid.attach(button_copy,2,5,1,1);
            grid.attach(button_start,0,6,1,1);
            grid.attach(button_stop,1,6,1,1);
            grid.attach(button_reboot,2,6,1,1);
            this.add((grid));

            button_start.set_sensitive(button_lock.active);
            button_stop.set_sensitive(button_lock.active);
            button_reboot.set_sensitive(button_lock.active);

            Gtk.Image lock_image = new Gtk.Image.from_icon_name("changes-prevent-symbolic.symbolic",Gtk.IconSize.MENU);
            Gtk.Image unlock_image = new Gtk.Image.from_icon_name("changes-allow-symbolic.symbolic",Gtk.IconSize.MENU);

            button_lock.set_image(lock_image);
            button_lock.set_always_show_image(true);

            button_stop.clicked.connect(() => {
                if (droplet_list.has_selected() && droplet_list.selected_is_running()) {
                    droplet_list.add_stop();
                    label_status.set_text("Shutdown sent. This may take a minute to complete.");
                    Timeout.add_seconds_full(GLib.Priority.DEFAULT, 5, () => {
                        label_status.set_text("");
                        return false;
                    });
                }
            });

            button_start.clicked.connect(() => {
                if (droplet_list.has_selected() && !droplet_list.selected_is_running()) {
                    droplet_list.add_start();
                    label_status.set_text("Startup sent. This may take a minute to complete.");
                    Timeout.add_seconds_full(GLib.Priority.DEFAULT, 5, () => {
                        label_status.set_text("");
                        return false;
                    });
                }
            });

            button_reboot.clicked.connect(() => {
                if (droplet_list.has_selected()) {
                    droplet_list.add_reboot();
                    label_status.set_text("Reboot sent. This may take a minute to complete.");
                    Timeout.add_seconds_full(GLib.Priority.DEFAULT, 5, () => {
                        label_status.set_text("");
                        return false;
                    });
                }
            });

            button_refresh.clicked.connect(() => {
                button_refresh.set_sensitive(false);
                droplet_list.update();
                Timeout.add_seconds_full(GLib.Priority.DEFAULT, 10, () => { 
                    button_refresh.set_sensitive(true);
                    return false;
                });
            });

            button_copy.clicked.connect (() => {
                if (droplet_list.has_selected()) {
                    Gdk.Display display = Gdk.Display.get_default ();
                    Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
                    string copy_ip = droplet_list.get_selected_ip();
                    clipboard.set_text(copy_ip, copy_ip.length);
                }
            });

            button_lock.toggled.connect (() => {
                if (button_lock.active) {
                    button_lock.set_image(unlock_image);
                } else {
                    button_lock.set_image(lock_image);
                }
                button_start.set_sensitive(button_lock.active);
                button_stop.set_sensitive(button_lock.active);
                button_reboot.set_sensitive(button_lock.active);
            });

            this.get_child().show_all();

        }

        // These are here to give parent access to certain methods

        public void update_token (string new_token) {
            droplet_list.update_token(new_token);
        }

        public void unselect_droplet() {
            droplet_list.unselect_all();
        }

        public void update() {
            droplet_list.update();
        }

        public void quit_scan() {
            droplet_list.quit_scan();
        }
    }

}