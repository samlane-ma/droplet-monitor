/*
 *  Droplet Monitor for the Budgie Panel
 *
 *  Copyright © 2022 Samuel Lane
 *  http://github.com/samlane-ma/
 *
 *  This applet is no way associated with Digital Ocean™.
 *  Digtal Ocean and Droplets are Copyright of DigitalOcean, LLC
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */


using Gtk, Gdk;
using DropletPopover;

namespace DropletApplet {

    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {

        public Budgie.Applet get_panel_widget(string uuid){
            return new DropletApplet(uuid);
        }
    }

    public class DropletSettings : Gtk.Grid {

        GLib.Settings? settings;

        private void on_update_clicked(string new_token) {
            if (new_token != "") {
               set_token(new_token);
            }
        }

        public DropletSettings(GLib.Settings? settings) {

            this.settings = settings;
            Gtk.Entry entry_token = new Gtk.Entry();
            Gtk.LinkButton link = new Gtk.LinkButton.with_label(
                "https://docs.digitalocean.com/reference/api/create-personal-access-token/",
                "For info on how to obtain your\npersonal Digital Ocean™ token"
            );

            this.attach(link,0,0,1,1);
            Gtk.Label label_token = new Gtk.Label("Droplet Manager Token:");
            Gtk.Button button_update = new Gtk.Button();
            button_update.set_label("Update Token");
            this.attach(label_token,0,1,1,1);
            this.attach(entry_token,0,2,3,1);
            this.attach(button_update,0,3,1,1);

            button_update.clicked.connect(() => {
                on_update_clicked(entry_token.get_text().strip());
                entry_token.set_text("");
            });

            this.show_all();
        }

        private void set_token(string new_token) {
            try {
                string tokendir = GLib.Environment.get_user_config_dir();
                string tokenfile = GLib.Path.build_filename(tokendir, ".dotoken");
                FileUtils.set_contents (tokenfile, new_token);

            } catch (Error e) {
                message("%s\n", e.message);
            }
        }

    }

    public class DropletApplet : Budgie.Applet {

        private Gtk.EventBox widget;
        private Gtk.Image icon;
        private DropletPopover.DropletPopover? popover = null;
        private unowned Budgie.PopoverManager? manager = null;
        private string token = "";
        private string tokendir;
        private string tokenfile;
        private File file;
        private FileMonitor monitor;
        private NetworkMonitor netmon;

        public string uuid { public set; public get; }

        public DropletApplet(string uuid) {
            Object(uuid: uuid);

            tokendir = GLib.Environment.get_user_config_dir();
            tokenfile = GLib.Path.build_filename(tokendir, ".dotoken");

            token = get_token(tokenfile);

            icon = new Gtk.Image.from_icon_name("do-server-error-symbolic", Gtk.IconSize.MENU);
            widget = new Gtk.EventBox();
            widget.add(icon);
            popover = new DropletPopover.DropletPopover(widget, token);
            add(widget);

            widget.button_press_event.connect((e)=> {
                if (e.button != 1) {
                    return Gdk.EVENT_PROPAGATE;
                }
                if (popover.get_visible()) {
                    popover.hide();
                } else {
                    this.manager.show_popover(widget);
                }
                return Gdk.EVENT_STOP;
            });

            popover.get_child().show_all();
            show_all();

            netmon = NetworkMonitor.get_default ();
            Timeout.add_seconds_full(GLib.Priority.DEFAULT, 10, () => {
                netmon.network_changed.connect (() => {
                    popover.unselect_droplet();
                    popover.update();
                });
                return false;
            });


            try {
                file = File.new_for_path (tokenfile);
		        monitor = file.monitor (FileMonitorFlags.NONE, null);
            } catch (Error e) {
                message("Error: %s", e.message);
            }

		    monitor.changed.connect(() => {
                popover.unselect_droplet();
			    popover.update_token(get_token(tokenfile));
		    });

        }

        private string get_token(string tokenfile) {
            string line = "";
            File file = File.new_for_path (tokenfile);
            if (!file.query_exists()) {
                try {
                    FileUtils.set_contents (tokenfile, "Enter token here");
                } catch (Error e) {
                    message("Error: %s\n", e.message);
                }

            } else {
                try {
		            FileInputStream @is = file.read ();
		            DataInputStream dis = new DataInputStream (@is);
		            line = dis.read_line().strip();
	            } catch (Error e) {
		            message("Error: %s\n", e.message);
                }
	        }
	        return (line);
        }

        public override void update_popovers(Budgie.PopoverManager? manager) {
            this.manager = manager;
            manager.register_popover(widget, popover);
        }

        public override bool supports_settings() {
            // Return true if settings should be in Budgie Desktop Settings
            // Return false if there are no settings
            return true;
        }

        public override Gtk.Widget? get_settings_ui() {
            return new DropletSettings(this.get_applet_settings(uuid));
        }

    }
}

[ModuleInit]
public void peas_register_types(TypeModule module) {

    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Budgie.Plugin), typeof(DropletApplet.Plugin));
}
