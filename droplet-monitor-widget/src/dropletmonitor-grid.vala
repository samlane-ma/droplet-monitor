/*
 * This file is part of the Budgie Droplet Monitor applet
 *
 * Copyright Samuel Lane
 * Website=https://github.com/samlane-ma/droplet-monitor
 *
 * This program is free software: you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version
 * 3 of the License, or (at your option) any later version.
 */

namespace DropletMonitorWidget {

public class DropletMonitorGrid : Gtk.Grid {

    private WidgetDropletList droplet_list;
    private Gtk.Widget[] action_widgets = {};
    private Gtk.Widget[] ssh_widgets = {};
    private Gtk.ScrolledWindow scrolled;
    private Gtk.Entry entry_ssh;
    private Gtk.Label label_ssh;
    private Gtk.Label label_status;
    private Gtk.Label label_at;
    private Gtk.Button button_ssh;
    private Gtk.Box box_ssh;
    private Gtk.ToggleButton button_lock;
    private Gtk.Button button_copy;
    private Gtk.Separator separator;
    private bool show_ssh = false;
    private GLib.Settings settings;
    /* Depth keeps track of how many times a button that changes the status label
     * has been clicked, that way the label is cleared only after the latest
     * callback has been completed.
     */
    private int depth = 0;

    private Gtk.Image LOCK_IMAGE;
    private Gtk.Image UNLOCK_IMAGE;

    public DropletMonitorGrid (WidgetDropletList dl, GLib.Settings settings) {

        this.settings = settings;
        this.droplet_list = dl;
        this.set_column_homogeneous(true);
        this.set_column_spacing(5);
        this.set_row_spacing(5);

        LOCK_IMAGE = new Gtk.Image.from_icon_name("droplet-action-lock-symbolic", 24);
        UNLOCK_IMAGE = new Gtk.Image.from_icon_name("droplet-action-unlock-symbolic", 24);
        LOCK_IMAGE.set_pixel_size(24);
        UNLOCK_IMAGE.set_pixel_size(24);

        string[] button_images = { "droplet-action-lock-symbolic", "droplet-action-refresh-symbolic", "droplet-action-copy-symbolic",
                                   "droplet-action-start-symbolic", "droplet-action-stop-symbolic", "droplet-action-reboot-symbolic" };
        string[] tool_tips = { "Toggle actions", "Refresh Droplet list", "Copy selected IP address",
                               "Start selected droplet", "Stop selected droplet", "Reboot selected droplet"};
        button_lock = new Gtk.ToggleButton();
        Gtk.Button button_refresh = new Gtk.Button();
		Gtk.Button button_start = new Gtk.Button();
		Gtk.Button button_stop = new Gtk.Button();
		button_copy = new Gtk.Button();
		Gtk.Button button_reboot = new Gtk.Button();
        Gtk.Button[] buttons = { button_lock, button_refresh, button_copy,
                                 button_start, button_stop, button_reboot };

        Gtk.Box button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        button_box.set_halign(Gtk.Align.FILL);
        for(int i = 0; i < 6; i++) {
            Gtk.Image img = new Gtk.Image.from_icon_name(button_images[i], 24);
            img.set_pixel_size(24);
            buttons[i].set_image(img);
            buttons[i].set_always_show_image(true);
            buttons[i].set_relief(Gtk.ReliefStyle.NONE);
            buttons[i].set_hexpand(true);
            buttons[i].set_halign(Gtk.Align.FILL);
            buttons[i].set_tooltip_text(tool_tips[i]);
            button_box.pack_start(buttons[i], false, false, 5);
        }

        label_status = new Gtk.Label(" ");
        scrolled = new Gtk.ScrolledWindow(null, null);
        scrolled.add(droplet_list);
        scrolled.set_size_request(-1, 80);

        box_ssh = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        build_ssh_box(box_ssh);

        separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        this.attach(scrolled,0,0,3,1);
        this.attach(label_status,0,1,3,1);
        this.attach(separator,0,2,3,1);
        this.attach(box_ssh,0,3,3,1);
        this.attach(new Gtk.Separator(Gtk.Orientation.HORIZONTAL),0,4,3,1);
        this.attach(button_box,0,5,3,1);

        show_ssh = settings.get_boolean("show-ssh");
        ssh_widgets = { label_ssh, label_at, button_ssh, entry_ssh };
        foreach (Gtk.Widget w in ssh_widgets) {
            w.set_sensitive(false);
        }
        action_widgets = { button_start, button_stop, button_reboot };
        foreach (Gtk.Widget w in action_widgets) {
            w.set_sensitive(false);
        }

        button_lock.set_image(LOCK_IMAGE);
        button_lock.set_always_show_image(true);

        button_stop.clicked.connect(() => {
            send_action(OFF, button_stop);
        });
        button_start.clicked.connect(() => {
            send_action(ON, button_start);
        });
        button_reboot.clicked.connect(() => {
            send_action(REBOOT, button_reboot);
        });
        button_refresh.clicked.connect(on_refresh_clicked);
        button_copy.clicked.connect (on_copy_clicked);
        droplet_list.row_selected.connect(on_row_selected);
        button_lock.toggled.connect (on_action_lock_toggled);
        entry_ssh.activate.connect(on_ssh_clicked);
        button_ssh.clicked.connect(on_ssh_clicked);
        droplet_list.update_count.connect(on_count_updated);

        button_copy.set_sensitive(false);
        settings.changed["show-ssh"].connect(on_show_ssh_changed);

        Idle.add(() => {
            box_ssh.set_visible(show_ssh);
            separator.set_visible(show_ssh);
            return false;
        });
    }

    private void build_ssh_box(Gtk.Box box) {
        button_ssh = new Gtk.Button();
        Gtk.Image ssh_image = new Gtk.Image.from_icon_name("droplet-action-ssh-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        button_ssh.set_image(ssh_image);
        button_ssh.set_tooltip_text("Open SSH connection");
        button_ssh.set_always_show_image(true);
        button_ssh.set_relief(Gtk.ReliefStyle.NONE);
        entry_ssh = new Gtk.Entry();
        entry_ssh.set_text("root");
        entry_ssh.set_alignment(1);
        entry_ssh.set_width_chars(8);
        entry_ssh.set_hexpand(true);
        label_at = new Gtk.Label("@");
        label_ssh = new Gtk.Label("");
        label_ssh.set_xalign(0);
        label_ssh.set_width_chars(15);
        box.pack_start(entry_ssh, true, true, 3);
        box.pack_start(label_at, false, false, 3);
        box.pack_start(label_ssh, false, false, 3);
        box.pack_start(button_ssh, false, false, 3);
    }

    private void on_show_ssh_changed () {
        show_ssh = settings.get_boolean("show-ssh");
        box_ssh.set_visible(show_ssh);
        separator.set_visible(show_ssh);
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
            depth += 1;
            label_status.set_text("%s copied!".printf(copy_ip));
            Timeout.add_seconds_full(GLib.Priority.DEFAULT, 5, restore_status_label);
        }
    }

    private bool restore_status_label() {
        depth -= 1;
        if (depth == 0) label_status.set_text("");
        return false;
    }

    private void on_row_selected(Gtk.ListBox box, Gtk.ListBoxRow? row) {
        bool has_selection = false;
        string current_selection = "";
        if (row != null) {
            has_selection = droplet_list.has_selected();
            current_selection = droplet_list.get_selected_ip();
        }
        label_ssh.set_label(current_selection);
        button_copy.set_sensitive(has_selection);
        foreach (Gtk.Widget w in action_widgets) {
            w.set_sensitive(has_selection && button_lock.active);
        }
        foreach (Gtk.Widget w in ssh_widgets) {
            // Dont't enable SSH unless an active droplet is selected
            w.set_sensitive(has_selection && droplet_list.selected_is_running());
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
            w.set_sensitive(lockbutton.active && droplet_list.has_selected());
        }
    }

    private void on_count_updated(int count) {
        // This keeps the scrolled window from getting too small or too big
        // more reliably than set_min/max_content_height does
        int size = 26 * count;
        if (size > 104) size = 108;
        if (size < 50) size = 50;
        scrolled.set_size_request(-1, size);
    }

    private void send_action (int action, Gtk.Button button) {
        if (!droplet_list.has_selected()) return;
        string[] action_name = {"Shutdown", "Startup", "Reboot"};
        if (action == ON && droplet_list.selected_is_running()) {
            return;
        }
        if (action == OFF && !droplet_list.selected_is_running()) {
            return;
        }
        depth += 1;
        button.set_sensitive(false);
        label_status.set_text(@"$(action_name[action]) sent. Please wait...");
        droplet_list.do_action(action);
        Timeout.add_seconds_full(GLib.Priority.DEFAULT, 5, () => {
            restore_status_label();
            button.set_sensitive(button_lock.get_active() && droplet_list.has_selected());
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
