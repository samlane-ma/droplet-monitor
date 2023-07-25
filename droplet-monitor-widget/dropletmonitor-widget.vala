
public class DropletMonitorPlugin : Budgie.RavenPlugin, Peas.ExtensionBase {
	public Budgie.RavenWidget new_widget_instance(string uuid, GLib.Settings? settings) {
		return new DropletMonitorWidget(uuid, settings);
	}

	public bool supports_settings() {
		return false;
	}
}

public class DropletMonitorWidget : Budgie.RavenWidget {

	private WidgetDropletList.WidgetDropletList droplet_list;
	private DropletMonitorGrid.DropletMonitorGrid dm_grid;
	private Gtk.Image? icon;
	private Gtk.Label label_ssh;
	private string token = "";
	private string? password;
	private Gtk.Revealer? content_revealer = null;

	public DropletMonitorWidget(string uuid, GLib.Settings? settings) {
		initialize(uuid, settings);

		Gtk.Label label_ssh = new Gtk.Label("");
		icon = new Gtk.Image.from_icon_name("do-server-ok-symbolic", Gtk.IconSize.MENU);
		icon.margin = 4;
		icon.margin_start = 12;
		icon.margin_end = 10;
		droplet_list = new WidgetDropletList.WidgetDropletList(token, icon, label_ssh);

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

		dm_grid = new DropletMonitorGrid.DropletMonitorGrid(droplet_list);
		
		content.add(dm_grid);
		show_all();
	}
}

[ModuleInit]
public void peas_register_types(TypeModule module) {
	// boilerplate - all modules need this
	var objmodule = module as Peas.ObjectModule;
	objmodule.register_extension_type(typeof(Budgie.RavenPlugin), typeof(DropletMonitorPlugin));
}
