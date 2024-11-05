/* application.vala
 *
 * Copyright 2024 Unknown
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[GtkTemplate (ui = "/io/gitlab/vgmkr/dot/ui/simple.ui")]
public class Gtkdot.GraphWindow : Gtk.ApplicationWindow {

	[GtkChild] private unowned Gtkdot.SimpleGraph view;
	[GtkChild] private unowned Gtk.Label na;
	[GtkChild] private unowned Gtk.Button nb;
	[GtkChild] private unowned Gtk.Image i1;


	private int initial_h = -1;
	private int initial_w = -1;

	private string[] icons = {
			"dialog-password-symbolic",
			"non-starred-symbolic",
			"security-medium-symbolic",
			"emblem-system-symbolic",
			"user-trash-symbolic",
			"tab-new-symbolic",
			"weather-few-clouds-symbolic",
			"weather-showers-symbolic"
		};

	public GraphWindow (Gtk.Application app) {
		Object (application: app);
		add_action_entries ({
			{ "delete", this.remove_selected },
			{ "select-all", this.select_all },
		}, this);
	}

	private void select_all () {
		this.view.select_all();
	}

	[GtkCallback]
	private void configure_graph () {

		this.view.enable_selection();
		this.view.border_color.parse("#6F4E37");
		this.view.border_color.alpha = 0.5f;
		this.view.shadow.color.parse("#9d8b7c");
		this.view.selection_color.parse("#cb4335");

		// this.get_settings().gtk_application_prefer_dark_theme = true;
		print("gtk_theme_name: %s\n",
			this.get_settings().gtk_theme_name

		);
		this.get_style_context ();

		unowned	var graph = this.view.get_graph();

		graph.safe_set("ratio", "compress", "" );
		// graph.safe_set("rankdir", "BT", "" );
		graph.safe_set("rankdir", "LR", "" );
		// graph.safe_set("pad", "0.4", "" );

	}

	[GtkCallback]
	private void pic_clicked (Gtk.Widget btn) {
		// i1.paintable = this.view.layout.get_dot_picture();
	}

	[GtkCallback]
	private void remove_selected () {
		this.view.remove_selected();
		// this.view.queue_draw();
	}

	[GtkCallback]
	private void generate_click (Gtk.Button btn) {

		Gtk.Button new_btn = new Gtk.Button.from_icon_name( icons[ GLib.Random.int_range(0, icons.length) ]);
		// Gtk.Button new_btn = new Gtk.Button.with_label("btn %d".printf( (int) view.n_members ) );
		// int size = int.max( 50, GLib.Random.int_range(50, 150) );
		// new_btn.set_size_request(size, size);
		new_btn.clicked.connect(this.generate_click);

		Gtk.Widget* ptr = child;
		print(" -> Add new button %p label:%s\n", ptr, new_btn.label );

		this.view.add_full_node( new_btn );
		this.view.add_full_edge( btn, new_btn );

	}

	public void generate_widgets(int n_nodes, int n_edges) {
		Gtk.Button[] nodes = {};
		Gtk.Button widget;

		for ( int i = 0; i < n_nodes; i ++ ) {
			if ( i % 2 == 0 )
				widget = new Gtk.Button.from_icon_name (
						icons[ GLib.Random.int_range(0, icons.length) ] );
			else
				widget = new Gtk.Button.with_label("%d".printf(i));

			if ( i % 2 == 0 )
				widget.clicked.connect(this.generate_click);
			else
				widget.clicked.connect( (b)=>{
					b.visible = false;
				});


			int margin = ( i % 3 == 0 )
				? int.max( 0, GLib.Random.int_range(10, 20) )
				: 0;
			widget.margin_top    = margin;
			widget.margin_bottom = margin;
			widget.margin_start  = margin;
			widget.margin_end    = margin;
			// widget.halign = Gtk.Align.CENTER;
/*
			int size = int.max( 50, GLib.Random.int_range(50, 150) );
			widget.set_size_request(size, size);
*/
			this.view.add_full_node( widget );
			nodes += widget;

		}

		for ( int i = 0; i < n_edges; i ++ ) {
			this.view.add_full_edge(
				nodes [ (int) GLib.Random.int_range(0, n_nodes) ],
				nodes [ (int) GLib.Random.int_range(0, n_nodes) ]
			);
		}

	}



}

public class Gtkdot.Application : Gtk.Application {

	public Application () {
		Object (
			application_id: "io.gitlab.vgmkr.dot",
			flags: ApplicationFlags.HANDLES_COMMAND_LINE
		);
	}

	construct {
		ActionEntry[] action_entries = {
			{ "quit", this.quit }
		};
		this.add_action_entries (action_entries, this);
		this.set_accels_for_action ("app.quit", {"<primary>q"});
		this.set_accels_for_action ("win.delete", {"Delete"});
		this.set_accels_for_action ("win.select-all", {"<primary>a"});
	}

	public override int command_line (ApplicationCommandLine command_line) {
		// keep the application running until we are done with this commandline
		this.hold ();

		int n_nodes = 10;
		int n_edges = 10;
		OptionEntry[] options = new OptionEntry[2];
		options[0] = { "nodes", 'n', OptionFlags.NONE, OptionArg.INT, ref n_nodes, "Number of nodes to generate", null };
		options[1] = { "edges", 'e', OptionFlags.NONE, OptionArg.INT, ref n_edges, "Number of edges to generate", null };

		var ctx = new OptionContext("Gtkdot Demo");
		ctx.add_main_entries (options, null);

		string[] argv = command_line.get_arguments();
		ctx.parse_strv (ref argv);

		var win = new Gtkdot.GraphWindow (this);
		win.generate_widgets( n_nodes, n_edges );
		win.present ();

		this.release ();
		// this.activate();
		return 0;
	}

	/*

	public override void activate () {

		// Initialize Widgets so that UI can find the classes
		typeof ( Gtkdot.Graph );

		base.activate ();

		var win = this.active_window;
		if (win == null) {
			win = new Gtkdot.GraphWindow (this);
		}
		win.present ();

	} */

}

int main (string[] args) {
	var app = new Gtkdot.Application ();
	return app.run (args);
}

