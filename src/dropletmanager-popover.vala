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
            Gtk.Button button_refresh = new Gtk.Button();
            button_refresh.set_label("Refresh");
            Gtk.Button button_start = new Gtk.Button();
            button_start.set_label("Start");
            Gtk.Button button_stop = new Gtk.Button();
            button_stop.set_label("Stop");
            Gtk.Label label_spacer = new Gtk.Label("");
            label_spacer.set_width_chars(50);
            Gtk.Label label_status = new Gtk.Label(" ");
            grid.attach(label_spacer,0,0,3,1);
            grid.attach(new Gtk.Separator(Gtk.Orientation.HORIZONTAL),0,1,3,1);
            grid.attach(droplet_list,0,2,3,1);
            grid.attach(label_status,0,3,3,1);
            grid.attach(new Gtk.Separator(Gtk.Orientation.HORIZONTAL),0,4,3,1);
            grid.attach(button_refresh,0,5,1,1);
            grid.attach(button_start,1,5,1,1);
            grid.attach(button_stop,2,5 ,1,1);
            this.add((grid));

            button_stop.clicked.connect(() => {
                if (droplet_list.has_selected() && droplet_list.is_selected_running()) {
                    droplet_list.toggle_selected(DOcean.OFF);
                    label_status.set_text("Shutdown sent. This may take a minute to complete.");
                    Timeout.add_seconds_full(GLib.Priority.DEFAULT, 5, () => {
                        label_status.set_text("");
                        return false;
                    });
                }
            });

            button_start.clicked.connect(() => {
                if (droplet_list.has_selected() && !droplet_list.is_selected_running()) {
                    droplet_list.toggle_selected(DOcean.ON);
                    label_status.set_text("Startup sent. This may take a minute to complete.");
                    Timeout.add_seconds_full(GLib.Priority.DEFAULT, 5, () => {
                        label_status.set_text("");
                        return false;
                    });
                }
            });

            button_refresh.clicked.connect(() => {
                droplet_list.update();
            });

            this.get_child().show_all();

        }

        // These are here to give parent access to certain

        public void update_token (string new_token) {
            droplet_list.update_token(new_token);
        }

        public void unselect_droplet() {
            droplet_list.unselect_all();
        }

        public void update() {
            droplet_list.update();
        }
    }

}