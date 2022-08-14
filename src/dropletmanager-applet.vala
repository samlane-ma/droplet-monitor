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

    public class DropletToken : Object {
        public static DropletPopover.DropletPopover? app_popover;
        public static string app_token;

        public void set_popover (DropletPopover.DropletPopover popover) {
            app_popover = popover;
        }

        public void update_token(string token) {
            if (app_popover != null) {
                app_token = token;
                app_popover.update_token(app_token);
            }
        }
    }

    public class DropletSettings : Gtk.Grid {

        GLib.Settings? settings;

        private void on_update_clicked(string new_token, DropletToken droplet_token) {
            if (new_token != "") {
                droplet_token.update_token(new_token);
                set_token(new_token);
            }
        }

        public DropletSettings(GLib.Settings? settings) {

            this.settings = settings;

            DropletToken droplet_token = new DropletToken();

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
                on_update_clicked(entry_token.get_text().strip(), droplet_token);
                entry_token.set_text("");
            });

            this.show_all();
        }

        private void set_token(string new_token) {
            var droplet_schema = new Secret.Schema ("com.github.samlane-ma.droplet-monitor",
                        Secret.SchemaFlags.NONE, 
                        "id", Secret.SchemaAttributeType.STRING,
                        "number", Secret.SchemaAttributeType.INTEGER, 
                        "even", Secret.SchemaAttributeType.BOOLEAN);
            var attributes = new GLib.HashTable<string,string> (str_hash, str_equal);
            attributes["id"] = "droplets";
            attributes["number"] = "8";
            attributes["even"] = "true";
            Secret.password_storev.begin (droplet_schema, attributes, Secret.COLLECTION_DEFAULT,
                                          "password", new_token, null, (obj, async_res) => {
                try {
                    Secret.password_store.end (async_res);
                } catch (Error e) {
                    message("Unable to store token in keyring: %s", e.message);
                }                   
            });
        }

    }

    public class DropletApplet : Budgie.Applet {

        private GLib.Settings? panel_settings;
        private GLib.Settings? currpanelsubject_settings;

        private Gtk.EventBox widget;
        private Gtk.Image icon;
        private DropletPopover.DropletPopover? popover = null;
        private unowned Budgie.PopoverManager? manager = null;
        private string token = "";
        private NetworkMonitor netmon;
        private string? password;

        public string uuid { public set; public get; }

        public DropletApplet(string uuid) {
            Object(uuid: uuid);

            var droplet_schema = new Secret.Schema ("com.github.samlane-ma.droplet-monitor",
                                 Secret.SchemaFlags.NONE,
                                 "id", Secret.SchemaAttributeType.STRING,
                                 "number", Secret.SchemaAttributeType.INTEGER,
                                 "even", Secret.SchemaAttributeType.BOOLEAN);
            var attributes = new GLib.HashTable<string,string> (str_hash, str_equal);
            attributes["id"] = "droplets";
            attributes["number"] = "8";
            attributes["even"] = "true";

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

            DropletToken droplet_token = new DropletToken();
            droplet_token.set_popover(popover);
            Secret.password_lookupv.begin (droplet_schema, attributes, null, (obj, async_res) => {
                try {
                    password = Secret.password_lookup.end (async_res);
                    if (password == null) {
                        password = "";
                    }
                } catch (Error e) {
                    message("Unable to retrieve token from keyring: %s", e.message);
                    password = "";
                }
                droplet_token.update_token(password);
            });

            netmon = NetworkMonitor.get_default ();
            Timeout.add_seconds_full(GLib.Priority.DEFAULT, 10, () => {
                netmon.network_changed.connect (() => {
                    popover.unselect_droplet();
                    popover.update();
                });
                return false;
            });

            popover.get_child().show_all();
            show_all();

            Idle.add(() => { 
                watch_applet(uuid);
                return false;});
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

        private bool find_applet(string find_uuid, string[] applet_list) {
            // Search panel applets for the given uuid
            for (int i = 0; i < applet_list.length; i++) {
                if (applet_list[i] == find_uuid) {
                    return true;
                }
            }
            return false;
        }

        private void watch_applet(string find_uuid) {
            // Check if the applet is still on the panel and ends cleanly if not
            string[] applets;
            string soluspath = "com.solus-project.budgie-panel";
            panel_settings = new GLib.Settings(soluspath);
            string[] allpanels_list = panel_settings.get_strv("panels");
            foreach (string p in allpanels_list) {
                string panelpath = "/com/solus-project/budgie-panel/panels/".concat("{", p, "}/");
                currpanelsubject_settings = new GLib.Settings.with_path(
                    soluspath + ".panel", panelpath
                );
                applets = currpanelsubject_settings.get_strv("applets");
                if (find_applet(find_uuid, applets)) {
                     currpanelsubject_settings.changed["applets"].connect(() => {
                        applets = currpanelsubject_settings.get_strv("applets");
                        if (!find_applet(find_uuid, applets)) {
                            popover.quit_scan();
                        }
                    });
                }
            }
        }
    }
}

[ModuleInit]
public void peas_register_types(TypeModule module) {

    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Budgie.Plugin), typeof(DropletApplet.Plugin));
}
