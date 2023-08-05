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

namespace DropletApplet {

private DropletList droplet_list;

[DBus (name = "com.github.samlane_ma.droplet_monitor")]
interface DOClient : GLib.Object {
    public abstract async DODroplet[] get_droplets () throws GLib.Error;
    public abstract async void set_token(string token) throws GLib.Error;
    public abstract async string send_droplet_signal(int mode, string droplet_id) throws GLib.Error;
    public signal void droplets_updated ();
    public signal void no_token ();
    public signal void token_updated(string newtoken);
}

    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {

        public Budgie.Applet get_panel_widget(string uuid){
            return new DropletApplet(uuid);
        }
    }


    public class DropletSettings : Gtk.Grid {

        GLib.Settings? settings;

        public DropletSettings(GLib.Settings? settings) {

            this.settings = settings;

            Gtk.Entry entry_token = new Gtk.Entry();
            Gtk.LinkButton link = new Gtk.LinkButton.with_label(
                "https://docs.digitalocean.com/reference/api/create-personal-access-token/",
                "For info on how to obtain your\npersonal Digital Ocean™ token"
            );

            this.attach(link,0,0,1,1);
            Gtk.Label label_token = new Gtk.Label("Droplet Monitor Token:");
            Gtk.Button button_update = new Gtk.Button();
            button_update.set_label("Update Token");
            this.attach(label_token,0,1,1,1);
            this.attach(entry_token,0,2,3,1);
            this.attach(button_update,0,3,1,1);
            this.attach(new Gtk.Label(""), 0, 4, 3, 1);
            Gtk.Label label_sort = new Gtk.Label("Sort Order:");
            label_sort.set_halign(Gtk.Align.START);
            this.attach(label_sort, 0, 5, 1, 1);
            
            Gtk.RadioButton button_name = new Gtk.RadioButton.with_label_from_widget (null, "Sort by Name");
            attach(button_name, 0, 6, 3, 1);
            Gtk.RadioButton button_offline_first = new Gtk.RadioButton.with_label_from_widget (button_name, "Sort Offline First");
            attach(button_offline_first, 0, 7, 3, 1);
            Gtk.RadioButton button_online_first = new Gtk.RadioButton.with_label_from_widget (button_name, "Sort Online First");
            attach(button_online_first, 0, 8, 3, 1);

            var sort_offline_first = settings.get_boolean("sort-offline-first");
            var sort_by_status = settings.get_boolean("sort-by-status");
            if (sort_by_status) {
                if (sort_offline_first) {
                    button_offline_first.set_active(true);
                } else {
                    button_online_first.set_active(true);
                }
            } else {
                button_name.set_active(true);
            }

            button_name.toggled.connect (sort_toggled);
            button_offline_first.toggled.connect (sort_toggled);
            button_online_first.toggled.connect (sort_toggled);

            button_update.clicked.connect(() => {
                set_token(entry_token.get_text().strip());
                entry_token.set_text("");
            });

            this.show_all();
        }

        private void sort_toggled (Gtk.ToggleButton button) {
            if (button.get_active() == false) {
                return;
            }
            if (button.label == "Sort by Name") {
                settings.set_boolean("sort-by-status", false);
            } else if (button.label == "Sort Offline First") {
                settings.set_boolean("sort-by-status", true);
                settings.set_boolean("sort-offline-first", true);
            } else {
                settings.set_boolean("sort-by-status", true);
                settings.set_boolean("sort-offline-first", false);
            }
        }

        private void set_token(string new_token) {
            if (new_token == "") {
                return;
            }
            droplet_list.update_token(new_token);
            // changes the token in the "Secret Service"
            var droplet_schema = new Secret.Schema ("com.github.samlane-ma.droplet-monitor",
                        Secret.SchemaFlags.NONE,
                        "id", Secret.SchemaAttributeType.STRING);
            var attributes = new GLib.HashTable<string,string> (str_hash, str_equal);
            attributes["id"] = "droplet-oauth";
            Secret.password_storev.begin (droplet_schema, attributes, Secret.COLLECTION_DEFAULT,
                                          "Droplet Monitor Token", new_token, null, (obj, async_res) => {
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
        private GLib.Settings settings;

        private Gtk.EventBox widget;
        private Gtk.Image icon;
        private DropletPopover? popover = null;
        private unowned Budgie.PopoverManager? manager = null;
        private string token = "";
        private string? password;

        public string uuid { public set; public get; }

        public DropletApplet(string uuid) {
            Object(uuid: uuid);

            this.settings_schema = "com.github.samlane-ma.droplet-monitor-applet";
            this.settings_prefix = "/com/solus-project/budgie-panel/instance/droplet-monitor-applet";
            this.settings = this.get_applet_settings(uuid);

            droplet_list = new DropletList(token);

            var droplet_schema = new Secret.Schema ("com.github.samlane-ma.droplet-monitor",
                                 Secret.SchemaFlags.NONE,
                                 "id", Secret.SchemaAttributeType.STRING);
            var attributes = new GLib.HashTable<string,string> (str_hash, str_equal);
            attributes["id"] = "droplet-oauth";

            icon = new Gtk.Image.from_icon_name("do-server-error-symbolic", Gtk.IconSize.MENU);
            widget = new Gtk.EventBox();
            widget.add(icon);
            popover = new DropletPopover(widget, droplet_list);
            add(widget);
            droplet_list.update_count.connect(on_count_updated);

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

            // set up the DropletToken class because Budgie Desktop Settings
            // needs it to update the token if applet is running
            Secret.password_lookupv.begin (droplet_schema, attributes, null, (obj, async_res) => {
                try {
                    password = Secret.password_lookup.end (async_res);
                    if (password == null) {
                        password = "";
                    }
                    droplet_list.update_token(password);
                } catch (Error e) {
                    message("Unable to retrieve token from keyring: %s", e.message);
                    password = "";
                }
             });

            popover.get_child().show_all();
            show_all();

            var sort_by_status = settings.get_boolean("sort-by-status");
            var sort_offline_first = settings.get_boolean("sort-offline-first");
            droplet_list.change_sort(true, sort_by_status, sort_offline_first);

            settings.changed.connect(() => {
                droplet_list.change_sort(true,
                    settings.get_boolean("sort-by-status"),
                    settings.get_boolean("sort-offline-first"));
            });

            Idle.add(() => {
                // watch_applet will monitor if the applet is removed
                watch_applet(uuid);
                return false;});
        }

        private void on_count_updated(int count, bool all_active) {
            if (count == 0) {
                icon.set_from_icon_name("do-server-error-symbolic", Gtk.IconSize.MENU);
            } else if (all_active) {
                icon.set_from_icon_name("do-server-ok-symbolic", Gtk.IconSize.MENU);
            } else {
                icon.set_from_icon_name("do-server-warn-symbolic", Gtk.IconSize.MENU);
            }
        }

        public override void update_popovers(Budgie.PopoverManager? manager) {
            this.manager = manager;
            manager.register_popover(widget, popover);
        }

        public override bool supports_settings() {
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
                            droplet_list.quit_scan();
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
