/*
 * MainWindow.vala
 *
 * Copyright 2012 Tony George <teejee2008@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

using Gtk;
using Gee;

using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using l.gtk;
using TeeJee.Misc;
using l.misc;

public class MainWindow : Gtk.Window {

	private Gtk.Box vbox_main;
	private Gtk.Box hbox_list;

	private Gtk.TreeView tv;
	private Gtk.Button btn_install;
	private Gtk.Button btn_uninstall;
	private Gtk.Button btn_ppa;
	private Gtk.Label lbl_info;

	// helper members

	private Gee.ArrayList<LinuxKernel> selected_kernels;

	public MainWindow() {

		title = BRANDING_LONGNAME;
		//window_position = WindowPosition.CENTER;
		window_position = WindowPosition.NONE;
		icon = get_app_icon(16);

		// vbox_main
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_main.margin = 6;

		vbox_main.set_size_request(App._window_width,App._window_height);
		App._window_width = App.window_width;
		App._window_height = App.window_height;

		add (vbox_main);

		selected_kernels = new Gee.ArrayList<LinuxKernel>();

		init_ui();

		if (App.command == "install") do_install(new LinuxKernel.from_version(App.requested_version));

		update_cache();

	}

	private void init_ui() {
		init_treeview();
		init_actions();
		init_infobar();

		this.resize(App.window_width,App.window_height);
		if (App.window_x >=0 && App.window_y >= 0) this.move(App.window_x,App.window_y);
		App._window_x = App.window_x;
		App._window_y = App.window_y;
	}

	private void init_treeview() {

		// hbox
		hbox_list = new Gtk.Box(Orientation.HORIZONTAL, 6);
		//hbox.margin = 6;
		vbox_main.add(hbox_list);

		//add treeview
		tv = new TreeView();
		tv.get_selection().mode = SelectionMode.MULTIPLE;
		tv.headers_visible = true;
		tv.expand = true;

		tv.row_activated.connect(tv_row_activated);

		tv.get_selection().changed.connect(tv_selection_changed);

		var scrollwin = new ScrolledWindow(((Gtk.Scrollable) tv).get_hadjustment(), ((Gtk.Scrollable) tv).get_vadjustment());
		scrollwin.set_shadow_type (ShadowType.ETCHED_IN);
		scrollwin.add (tv);
		hbox_list.add(scrollwin);

		//column
		var col = new TreeViewColumn();
		col.title = _("Kernel");
		col.resizable = true;
		col.set_sort_column_id(0);
		col.set_sort_indicator(true);
		col.sort_indicator = true;
		col.min_width = 200;
		tv.append_column(col);

		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf ();
		cell_pix.xpad = 4;
		cell_pix.ypad = 6;
		col.pack_start (cell_pix, false);
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter)=>{
			Gdk.Pixbuf pix;
			model.get (iter, 2, out pix, -1);
			return_if_fail(cell as Gtk.CellRendererPixbuf != null);
			((Gtk.CellRendererPixbuf) cell).pixbuf = pix;
		});

		//cell text
		var cellText = new CellRendererText();
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cellText, false);
		col.set_cell_data_func (cellText, (cell_layout, cell, model, iter)=>{
			LinuxKernel kern;
			model.get (iter, 1, out kern, -1);
			return_if_fail(cell as Gtk.CellRendererText != null);
			((Gtk.CellRendererText) cell).text = kern.version_main;
		});

		//column
		col = new TreeViewColumn();
		col.title = _("Status");
		col.set_sort_column_id(3);
		col.set_sort_indicator(true);
		col.resizable = true;
		col.min_width = 200;
		tv.append_column(col);

		//cell text
		cellText = new CellRendererText();
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start(cellText, true);
		col.add_attribute(cellText, "text", 3);

		//column
		col = new TreeViewColumn();
		col.title = _("Notes");
		//col.set_sort_column_id(4); // not working ?
		col.resizable = true;
		col.min_width = 200;
		tv.append_column(col);

		//cell text
		cellText = new CellRendererText();
		cellText.ellipsize = Pango.EllipsizeMode.END;

		col.pack_start (cellText, false);
		col.set_cell_data_func(cellText, (cell_layout, cell, model, iter)=>{
			LinuxKernel k;
			model.get(iter, 1, out k, -1);
			return_if_fail(cell as Gtk.CellRendererText != null);
			((Gtk.CellRendererText) cell).text = k.notes;
		});

		cellText.editable = true;
		cellText.edited.connect((path,data) => {
			TreeIter iter;
			tv.model.get_iter_from_string(out iter, path);
			LinuxKernel k;
			tv.model.get(iter, 1, out k, -1);
			if (k.notes != data._strip()) {
				k.notes = data;
				file_write(k.notes_file,data);
			}
		});

		tv.set_tooltip_column(5);
	}

	private void tv_row_activated(TreePath path, TreeViewColumn column) {
		TreeIter iter;
		tv.model.get_iter_from_string(out iter, path.to_string());
		LinuxKernel k;
		tv.model.get (iter, 1, out k, -1);

		set_button_state();
	}

	private void tv_selection_changed() {
		var sel = tv.get_selection();

		TreeModel model;
		TreeIter iter;
		var paths = sel.get_selected_rows (out model);

		selected_kernels.clear();
		foreach (var path in paths) {
			LinuxKernel k;
			model.get_iter(out iter, path);
			model.get(iter, 1, out k, -1);
			selected_kernels.add(k);
		}

		set_button_state();
	}

	private void tv_refresh() {
		vprint("tv_refresh()",2);
		//								 0 index      1 kernel             2 icon              3 status        4 notes         5 tooltip
		var model = new Gtk.ListStore(6, typeof(int), typeof(LinuxKernel), typeof(Gdk.Pixbuf), typeof(string), typeof(string), typeof(string));

		Gdk.Pixbuf pix_ubuntu = null;
		Gdk.Pixbuf pix_mainline = null;
		Gdk.Pixbuf pix_mainline_rc = null;

		try {
			pix_ubuntu = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/ubuntu-logo.png");
			pix_mainline = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux.png");
			pix_mainline_rc = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux-red.png");
		}
		catch (Error e) {
			vprint(e.message,1,stderr);
		}

		int i = -1;
		TreeIter iter;
		foreach (var k in LinuxKernel.kernel_list) {
			if (k.is_invalid) continue;
			if (!k.is_installed) {
				if (k.is_unstable && App.hide_unstable) continue;
				if (k.version_maj < LinuxKernel.threshold_major) continue;
			}

			// add row
			model.append(out iter);
			model.set(iter, 0, ++i); // for sorting the "Kernel" column
			model.set(iter, 1, k);

			if (!k.is_invalid) {
				if (k.is_mainline) {
					if (k.is_unstable) model.set(iter, 2, pix_mainline_rc);
					else model.set (iter, 2, pix_mainline);
				} else model.set(iter, 2, pix_ubuntu);
			}

			model.set(iter, 3, k.status);

			//model.set(iter, 4, file_read(k.user_notes_file));

			model.set(iter, 5, k.tooltip_text());
		}

		tv.set_model(model);
		tv.columns_autosize();

		selected_kernels.clear();
		set_button_state();

		set_infobar();
	}

	private void set_button_state() {
		if (selected_kernels.size == 0) {
			btn_install.sensitive = false;
			btn_uninstall.sensitive = false;
			btn_ppa.sensitive = true;
		} else {
			// only allow selecting a single kernel for install/uninstall, examine the installed state
			btn_install.sensitive = (selected_kernels.size == 1) && !selected_kernels[0].is_installed;
			btn_uninstall.sensitive = selected_kernels[0].is_installed && !selected_kernels[0].is_running;
			btn_ppa.sensitive = (selected_kernels.size == 1) && selected_kernels[0].is_mainline;
			// allow selecting multiple kernels for install/uninstall, but IF only a single selected, examine the installed state
			// (the rest of the app does not have loops to process a list yet)
			//btn_install.sensitive = selected_kernels.size == 1 ? !selected_kernels[0].is_installed : true;
			//btn_uninstall.sensitive = selected_kernels.size == 1 ? selected_kernels[0].is_installed && !selected_kernels[0].is_running : true;
		}
	}

	private void init_actions() {

		var hbox = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_list.add (hbox);

		// install
		var button = new Gtk.Button.with_label (_("Install"));
		hbox.pack_start (button, true, true, 0);
		btn_install = button;

		button.clicked.connect(() => {
			return_if_fail(selected_kernels.size == 1);
			do_install(selected_kernels[0]);
		});

		// uninstall
		button = new Gtk.Button.with_label (_("Uninstall"));
		hbox.pack_start (button, true, true, 0);
		btn_uninstall = button;

		button.clicked.connect(() => {
			return_if_fail(selected_kernels.size > 0);
			do_uninstall(selected_kernels);
		});

		// ppa
		button = new Gtk.Button.with_label ("PPA");
		hbox.pack_start (button, true, true, 0);
		btn_ppa = button;

		button.clicked.connect(() => {
			string uri = App.ppa_uri;
			if (selected_kernels.size == 1) uri += selected_kernels[0].kname;
			uri_open(uri);
		});

		// uninstall-old
		button = new Gtk.Button.with_label (_("Uninstall Old"));
		button.set_tooltip_text(_("Uninstall all but the highest installed version"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_purge);

		// reload
		button = new Gtk.Button.with_label (_("Reload"));
		button.set_tooltip_text(_("Delete cache and reload all kernel info\n\nTHIS WILL ALSO DELETE ALL USER NOTES"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(reload_cache);

		// settings
		button = new Gtk.Button.with_label (_("Settings"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_settings);

		// about
		button = new Gtk.Button.with_label (_("About"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_about);

		// exit
		button = new Gtk.Button.with_label (_("Exit"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_exit);

	}

	private void do_settings () {
			int _previous_majors = App.previous_majors;
			bool _hide_unstable = App.hide_unstable;

			var dlg = new SettingsDialog.with_parent(this);
			dlg.run();
			dlg.destroy();

			if (
					(_previous_majors != App.previous_majors) ||
					(_hide_unstable != App.hide_unstable)
				) {
				//reload_cache();
				update_cache();
			}
	}

	private void do_exit () {
		Gtk.main_quit();
	}

	private void do_about () {

		var dialog = new AboutWindow();
		dialog.set_transient_for (this);

		// FIXME - this should come from the AUTHORS file, or from git
		dialog.authors = {
			"Tony George <teejeetech@gmail.com>",
			BRANDING_AUTHORNAME+" <"+BRANDING_AUTHOREMAIL+">"
		};

		// FIXME - generate this list from the .po files
		/*
		dialog.translators = {
			"name",
			"name",
			"name"
		};
		*/
		// For now, run "make TRANSLATORS"
		// then cut & paste from generated TRANSLATORS file
		// and add the quotes & commas
		dialog.translators = {
			"de: Marvin Meysel <marvin@meysel.net>",
			"el: Vasilis Kosmidis <skyhirules@gmail.com>",
			"es: Adolfo Jayme Barrientos <fitojb@ubuntu.com>",
			"fr: Yolateng0 <yo@yo.nohost.me>",
			"hr: gogo <trebelnik2@gmail.com>",
			"it: Albano Battistella <albano_battistella@hotmail.com>",
			"ko: Kevin Kim <root@hamonikr.org>",
			"nl: Heimen Stoffels <vistausss@outlook.com>",
			"pl: Viktor Sokyrko <victor_sokyrko@windowslive.com>",
			"ru: Danik2343 <krutalevex@mail.ru>",
			"sv: Åke Engelbrektson <eson@svenskasprakfiler.se>",
			"tr: Sabri Ünal <libreajans@gmail.com>",
			"uk: Serhii Golovko <cappelikan@gmail.com>",
		};

		dialog.documenters = null;
		dialog.artists = null;

		dialog.program_name = BRANDING_LONGNAME;
		dialog.comments = _("Kernel upgrade utility for Ubuntu-based distributions");
		dialog.copyright = _("Original")+": \"ukuu\" © 2015-18 Tony George\n"+_("Forked")+": \""+BRANDING_SHORTNAME+"\" 2019 "+BRANDING_AUTHORNAME+" ("+BRANDING_AUTHOREMAIL+")";
		dialog.version = BRANDING_VERSION;
		dialog.logo = get_app_icon(128);

		dialog.license = "This program is free for personal and commercial use and comes with absolutely no warranty. You use this program entirely at your own risk. The author will not be liable for any damages arising from the use of this program.";
		dialog.website = BRANDING_WEBSITE;
		dialog.website_label = BRANDING_WEBSITE;

		dialog.third_party = {
			"Elementary project (various icons):github.com/elementary/icons",
			"Tango project (various icons):tango.freedesktop.org/Tango_Desktop_Project",
			"notify-send.sh:github.com/bkw777/notify-send.sh"
		};

		dialog.initialize();
		dialog.show_all();
	}

	// Full re-load. Delete cache and clear session state and start over.
	private void reload_cache() {
		vprint("reload_cache()",2);
		LinuxKernel.delete_cache();
		App.ppa_tried = false;
		update_cache();
	}

	// Update the cache as optimally as possible.
	private void update_cache() {
		vprint("update_cache()",2);

		if (!try_ppa()) return;

		if (!App.GUI_MODE) {
			// refresh without GUI
			LinuxKernel.query(false);
			return;
		}

		string message = _("Updating kernels");
		var progress_window = new ProgressWindow.with_parent(this, message, true);
		progress_window.show_all();

		LinuxKernel.query(false, (timer, ref count, last) => {
			update_progress_window(progress_window, message, timer, ref count, last);
		});

		tv_refresh();
	}

	private void update_progress_window(ProgressWindow progress_window, string message, GLib.Timer timer, ref long count, bool last = false) {
		if (last) {
			progress_window.destroy();
			Gdk.threads_add_idle_full(0, () => {
				tv_refresh();
				return false;
			});
			timer_elapsed(timer, true);
		}

		App.status_line = LinuxKernel.status_line;
		App.progress_total = LinuxKernel.progress_total;
		App.progress_count = LinuxKernel.progress_count;

		Gdk.threads_add_idle_full(0, () => {
			if (App.progress_total > 0)
				progress_window.update_message("%s %s/%s".printf(message, App.progress_count.to_string(), App.progress_total.to_string()));

			progress_window.update_status_line(); 
			return false;
		});

		count++;
	}

	private void init_infobar() {

		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		//scrolled.margin = 6;
		scrolled.margin_top = 0;
		scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.vscrollbar_policy = Gtk.PolicyType.NEVER;
		vbox_main.add(scrolled);

		// hbox
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		//hbox.margin = 6;
		scrolled.add(hbox);

		lbl_info = new Gtk.Label("");
		lbl_info.margin = 6;
		lbl_info.set_use_markup(true);
		hbox.add(lbl_info);
	}

	private void set_infobar() {

		if (LinuxKernel.kernel_active != null) {

			lbl_info.label = _("Running")+" <b>%s</b>".printf(LinuxKernel.kernel_active.version_main);

			if (LinuxKernel.kernel_active.is_mainline) {
				lbl_info.label += " (mainline)";
			} else {
				lbl_info.label += " (ubuntu)";
			}

			if (LinuxKernel.kernel_latest_available.compare_to(LinuxKernel.kernel_latest_installed) > 0) {
				lbl_info.label += " ~ <b>%s</b> ".printf(LinuxKernel.kernel_latest_available.version_main)+_("available");
			}
		}
		else{
			lbl_info.label = _("Running")+" <b>%s</b>".printf(LinuxKernel.RUNNING_KERNEL);
		}
	}

	public void do_install(LinuxKernel k) {
		if (App.command == "install") App.command = "list";
		return_if_fail(!k.is_installed);
		// try even if we think the net is down
		// so the button responds instead of looking broken
		//if (!ppa_up()) return;

		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.configure_event.connect ((event) => {
			//log_debug("term resize: %dx%d@%dx%d".printf(event.width,event.height,event.x,event.y));
			App.term_width = event.width;
			App.term_height = event.height;
//			App.term_x = event.x;
//			App.term_y = event.y;
			return false;
		});

		term.script_complete.connect(()=>{
			term.allow_window_close();
			dir_delete(t_dir);
		});

		term.destroy.connect(()=>{
			this.present();
			update_cache();
		});

		string sh = BRANDING_SHORTNAME;
		if (App.index_is_fresh) sh += " --index-is-fresh";
		if (App.VERBOSE>1) sh += " --debug";
		sh += " --install %s\n".printf(k.version_main)
		+ "echo \n"
		+ "echo '"+_("DONE")+"'\n"
		;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
		vprint("------------------------------------------------------------------------------");
	}

	public void do_uninstall(Gee.ArrayList<LinuxKernel> klist) {
		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.configure_event.connect ((event) => {
			App.term_width = event.width;
			App.term_height = event.height;
			return false;
		});


		term.script_complete.connect(()=>{
			term.allow_window_close();
			dir_delete(t_dir);
		});

		term.destroy.connect(()=>{
			this.present();
			update_cache();
		});

		string names = "";
		foreach(var k in klist) {
			if (names.length > 0) names += ",";
			names += "%s".printf(k.version_main);
		}

		string sh = BRANDING_SHORTNAME;
		if (App.index_is_fresh) sh += " --index-is-fresh";
		if (App.VERBOSE>1) sh += " --debug";
			sh += " --uninstall %s\n".printf(names)
			+ "echo \n"
			+ "echo '"+_("DONE")+"'\n"
			;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
		vprint("------------------------------------------------------------------------------");
	}

	public void do_purge () {
		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.configure_event.connect ((event) => {
			App.term_width = event.width;
			App.term_height = event.height;
			return false;
		});


		term.script_complete.connect(()=>{
			term.allow_window_close();
			dir_delete(t_dir);
		});

		term.destroy.connect(()=>{
			this.present();
			update_cache();
		});

		string sh = BRANDING_SHORTNAME+" --uninstall-old";
		if (App.index_is_fresh) sh += " --index-is-fresh";
		if (App.VERBOSE>1) sh += " --debug";
			sh += "\n"
			+ "echo \n"
			+ "echo '"+_("DONE")+"'\n"
			;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
		vprint("------------------------------------------------------------------------------");
	}

}
