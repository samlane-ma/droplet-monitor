
namespace DropletMonitorWidget {

private WidgetDropletList droplet_list;

public class DropletMonitorPlugin : Budgie.RavenPlugin, Peas.ExtensionBase {
    public Budgie.RavenWidget new_widget_instance(string uuid, GLib.Settings? settings) {
        return new DropletMonitorWidget(uuid, settings);
    }

    public bool supports_settings() {
        return true;
    }
}

public class DropletMonitorWidgetSettings: Gtk.Grid  {

    private GLib.Settings? settings;

    public DropletMonitorWidgetSettings(GLib.Settings? settings) {

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

        button_update.clicked.connect(() => {
            set_token(entry_token.get_text().strip());
            entry_token.set_text("");
        });
        this.show_all();
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
                                      "password", new_token, null, (obj, async_res) => {
            try {
                Secret.password_store.end (async_res);
            } catch (Error e) {
                message("Unable to store token in keyring: %s", e.message);
            }
        });
    }
}

public class DropletMonitorWidget : Budgie.RavenWidget {

    private DropletMonitorGrid dm_grid;
    private Gtk.Image? icon;
    private GLib.Settings widget_settings;
    private string token = "";
    private string? password;
    private Gtk.Revealer? content_revealer = null;
    private ulong source;

    public DropletMonitorWidget(string uuid, GLib.Settings? settings) {
        initialize(uuid, settings);

        icon = new Gtk.Image.from_icon_name("do-server-ok-symbolic", Gtk.IconSize.MENU);
        icon.margin = 4;
        icon.margin_start = 12;
        icon.margin_end = 10;
        droplet_list = new WidgetDropletList(token);

        var droplet_schema = new Secret.Schema ("com.github.samlane-ma.droplet-monitor",
                             Secret.SchemaFlags.NONE,
                             "id", Secret.SchemaAttributeType.STRING);
        var attributes = new GLib.HashTable<string,string> (str_hash, str_equal);
        attributes["id"] = "droplet-oauth";

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

        var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        add(main_box);
        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        header.get_style_context().add_class("raven-header");
        main_box.add(header);
        header.add(icon);
        var header_label = new Gtk.Label("Droplet Monitor");
        header.add(header_label);
        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        content.get_style_context().add_class("raven-background");
        content_revealer = new Gtk.Revealer();
        content_revealer.add(content);
        content_revealer.reveal_child = true;
        main_box.add(content_revealer);
        var header_reveal_button = new Gtk.Button.from_icon_name("pan-down-symbolic", Gtk.IconSize.MENU);
        header_reveal_button.get_style_context().add_class("flat");
        header_reveal_button.get_style_context().add_class("expander-button");
        header_reveal_button.margin = 4;
        header_reveal_button.valign = Gtk.Align.CENTER;
        header_reveal_button.clicked.connect(() => {
            content_revealer.reveal_child = !content_revealer.child_revealed;
            var image = (Gtk.Image?) header_reveal_button.get_image();
            if (content_revealer.reveal_child) {
                image.set_from_icon_name("pan-down-symbolic", Gtk.IconSize.MENU);
            } else {
                image.set_from_icon_name("pan-end-symbolic", Gtk.IconSize.MENU);
            }
        });
        header.pack_end(header_reveal_button, false, false, 0);

        dm_grid = new DropletMonitorGrid(droplet_list);

        content.add(dm_grid);
        show_all();

        droplet_list.update_count.connect(on_count_updated);

        // This little bit stops the widget from updating after the widget is removed
        widget_settings =  new GLib.Settings("org.buddiesofbudgie.budgie-desktop.raven.widgets");
        source = widget_settings.changed["uuids"].connect(() => {
            if (!(uuid in widget_settings.get_strv("uuids"))) {
                droplet_list.quit_scan();
                widget_settings.disconnect(source);
            }
        });
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

    public override Gtk.Widget build_settings_ui() {
        return new DropletMonitorWidgetSettings(get_instance_settings());
    }
}

}

[ModuleInit]
public void peas_register_types(TypeModule module) {
    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Budgie.RavenPlugin), typeof(DropletMonitorWidget.DropletMonitorPlugin));
}
