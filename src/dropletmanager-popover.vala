using Gtk;
using DropletList;

namespace DropletPopover {

    public class DropletPopover : Budgie.Popover {

        private DropletList.DropletList droplet_list;

        void on_shutdown_clicked (DropletList.DropletList dl) {
            dl.shutdown_selected();
        }
        
        void on_startup_clicked (DropletList.DropletList dl) {
            dl.startup_selected();
        }

        public void update_token (string new_token) {
            droplet_list.update_token(new_token);
        }

        public void unselect_droplet() {
            droplet_list.unselect_all();
        }

        public DropletPopover(Gtk.EventBox relative_parent, string token) {
            Object(relative_to: relative_parent);

            droplet_list = new DropletList.DropletList(token);
            Gtk.Grid grid = new Gtk.Grid();
            grid.set_column_homogeneous(true);
            grid.set_column_spacing(10);

            droplet_list.set_update_icon((Gtk.Image) relative_parent.get_child());
            //Gtk.Button button_info = new Gtk.Button();
            //button_info.set_label("Information");
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
            //grid.attach(button_info,0,5,1,1);
            grid.attach(button_start,1,5,1,1);
            grid.attach(button_stop,2,5 ,1,1);
            this.add((grid));
            
            button_stop.clicked.connect(() => {
                if (droplet_list.has_selected() && droplet_list.is_selected_running()) {
                    on_shutdown_clicked(droplet_list);
                    label_status.set_text("Shutdown sent. This may take a minute to complete.");
                    Timeout.add_seconds_full(GLib.Priority.DEFAULT, 5, () => {
                        label_status.set_text("");
                        return false;
                    });
                }
            });
        
            button_start.clicked.connect(() => {
                if (droplet_list.has_selected() && !droplet_list.is_selected_running()) {
                    on_startup_clicked(droplet_list);
                    label_status.set_text("Startup sent. This may take a minute to complete.");
                    Timeout.add_seconds_full(GLib.Priority.DEFAULT, 5, () => {
                        label_status.set_text("");
                        return false;
                    });
                }
            });
            this.get_child().show_all();

        }
    }

}