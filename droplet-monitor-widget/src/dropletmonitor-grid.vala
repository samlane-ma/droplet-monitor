namespace DropletMonitorWidget {

public class DropletMonitorGrid : Gtk.Grid {

    private WidgetDropletList droplet_list;
    private Gtk.Widget[] action_widgets = {};
    private Gtk.ScrolledWindow scrolled;
    private Gtk.Entry entry_ssh;
    private Gtk.Label label_ssh;
    private Gtk.ToggleButton button_lock;

    private Gtk.Image LOCK_IMAGE = new Gtk.Image.from_icon_name(
        "changes-prevent-symbolic.symbolic",Gtk.IconSize.MENU);
    private Gtk.Image UNLOCK_IMAGE = new Gtk.Image.from_icon_name(
        "changes-allow-symbolic.symbolic",Gtk.IconSize.MENU);

        
    public DropletMonitorGrid (WidgetDropletList dl) {

        this.droplet_list = dl;
		this.set_column_homogeneous(true);
		this.set_column_spacing(5);
		this.set_row_spacing(5);

		Gtk.Button button_refresh = new Gtk.Button();
		Gtk.Button button_start = new Gtk.Button();
		Gtk.Button button_stop = new Gtk.Button();
		Gtk.Button button_copy = new Gtk.Button();
		Gtk.Button button_reboot = new Gtk.Button();
        Gtk.Label label_status = new Gtk.Label(" ");
		Gtk.Label label_spacer = new Gtk.Label("");
		label_spacer.set_width_chars(20);
        button_lock = new Gtk.ToggleButton();
		scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.add(droplet_list);
		scrolled.set_size_request(-1, 80);

		string[,] button_labels = { { "Actions", "Refresh", "Copy IP" },
									{ "Start", "Stop", "Reboot"  } };
		Gtk.Button[,] buttons = { { button_lock, button_refresh, button_copy },
								  { button_start, button_stop, button_reboot } };

		this.attach(scrolled, 0,0,3,1);
		this.attach(label_status,0,1,3,1);
		this.attach(new Gtk.Separator(Gtk.Orientation.HORIZONTAL),0,3,3,1);

		for (var row = 0; row < 2; row++) {
			for (var col = 0; col < 3; col++) {
				buttons[row, col].set_label(button_labels[row,col]);
				this.attach(buttons[row, col], col, row + 4, 1, 1);
			}
		}

		Gtk.Box box_ssh = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);
		Gtk.Button button_ssh = new Gtk.Button();
		button_ssh.set_label("SSH");
		entry_ssh = new Gtk.Entry();
		entry_ssh.set_text("root");
		entry_ssh.set_width_chars(10);
		entry_ssh.set_alignment(1);
		Gtk.Label label_at = new Gtk.Label("@");
        label_ssh = new Gtk.Label("");
		label_ssh.set_xalign(0);
		label_ssh.set_width_chars(15);
		box_ssh.pack_start(entry_ssh, false, false, 2);
		box_ssh.pack_start(label_at, false, false, 2);
		box_ssh.pack_start(label_ssh, false, false, 2);
		box_ssh.pack_end(button_ssh, false, false, 2);
		this.attach(box_ssh,0,7,3,1);

        action_widgets = { button_start, button_stop, button_reboot,
                           entry_ssh, button_ssh, label_at, label_ssh };
        foreach (Gtk.Widget w in action_widgets) {
            w.set_sensitive(false);
        }

        button_lock.set_image(LOCK_IMAGE);
        button_lock.set_always_show_image(true);

        button_stop.clicked.connect(() => {
            send_action(OFF, label_status, button_stop, button_lock);
        });
        button_start.clicked.connect(() => {
            send_action(ON, label_status, button_start, button_lock);
        });
        button_reboot.clicked.connect(() => {
            send_action(REBOOT, label_status, button_reboot, button_lock);
        });

        button_refresh.clicked.connect(on_refresh_clicked);
        button_copy.clicked.connect (on_copy_clicked);
        droplet_list.row_selected.connect(on_row_selected);
        button_lock.toggled.connect (on_action_lock_toggled);
        entry_ssh.activate.connect(on_ssh_clicked);
        button_ssh.clicked.connect(on_ssh_clicked);
        droplet_list.update_count.connect(on_count_updated);
    }

    private void on_refresh_clicked(Gtk.Button button) {
        button.set_sensitive(false);
        droplet_list.update();
        Timeout.add_seconds_full(GLib.Priority.DEFAULT, 10, () => {
            button.set_sensitive(true);
            return false;
        });
    }

    private void on_copy_clicked(Gtk.Button button) {
        if (droplet_list.has_selected()) {
            Gdk.Display display = Gdk.Display.get_default ();
            Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
            string copy_ip = droplet_list.get_selected_ip();
            clipboard.set_text(copy_ip, copy_ip.length);
        }
    }

    private void on_row_selected(Gtk.ListBox box, Gtk.ListBoxRow? row) {
        bool has_selection = false;
        string current_selection = "";
        if (row != null) {
            has_selection = droplet_list.has_selected();
            current_selection = droplet_list.get_selected_ip();
        }
        label_ssh.set_label(current_selection);
        foreach (Gtk.Widget w in action_widgets) {
            w.set_sensitive(has_selection && button_lock.active);
        }
    }

    private void on_ssh_clicked(Gtk.Widget widget) {
        if (droplet_list.has_selected() && droplet_list.selected_is_running()) {
            run_ssh(entry_ssh.get_text(), droplet_list.get_selected_ip());
        }
    }

    private void on_action_lock_toggled(Gtk.ToggleButton lockbutton) {
        if (lockbutton.active) {
            lockbutton.set_image(UNLOCK_IMAGE);
        } else {
            lockbutton.set_image(LOCK_IMAGE);
        }
        foreach (Gtk.Widget w in action_widgets) {
            w.set_sensitive(lockbutton.active);
        }
    }

    private void on_count_updated(int count) {
        int size = 25 * count;
        if (size > 115) size = 130;
        if (size < 52) size = 52;
        scrolled.set_size_request(-1, size);
    }

    private void send_action (int action, Gtk.Label status, Gtk.Button button, Gtk.ToggleButton lock) {
        if (!droplet_list.has_selected()) return;
        string[] action_name = {"Shutdown", "Startup", "Reboot"};
        if (action == ON && droplet_list.selected_is_running()) {
            return;
        }
        if (action == OFF && !droplet_list.selected_is_running()) {
            return;
        }
        button.set_sensitive(false);
        status.set_text(@"$(action_name[action]) sent. Please wait...");
        droplet_list.do_action(action);
        Timeout.add_seconds_full(GLib.Priority.DEFAULT, 5, () => {
            status.set_text("");
            button.set_sensitive(lock.get_active());
            return false;
        });
    }

    private void run_ssh(string user, string ip) {
        // if on Debian based distros we can open the users preferred terminal, else
        // we will let GLib pick a terminal with its own preferred order
        string? terminal = Environment.find_program_in_path ("x-terminal-emulator");
        try {
            AppInfo appinfo;
            if (terminal != null) {
                appinfo = AppInfo.create_from_commandline(@"$terminal -e ssh $user@$ip", terminal,
                                                               AppInfoCreateFlags.NONE);
            } else {
                appinfo = AppInfo.create_from_commandline(@"ssh $user@$ip", "ssh",
                                                              AppInfoCreateFlags.NEEDS_TERMINAL);
            }
            appinfo.launch(null, null);
        } catch (Error e) {
            warning ("Error launching ssh: %s", e.message);
        }
    }

}

}
