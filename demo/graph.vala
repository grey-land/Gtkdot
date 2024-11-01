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

[GtkTemplate (ui = "/io/gitlab/vgmkr/dot/ui/graph.ui")]
public class Gtkdot.GraphWindow : Gtk.ApplicationWindow {

	[GtkChild] private unowned Gtkdot.Graph view;
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
		this.view.enable_selection();
		this.view.realize.connect( ()=>{
			this.scale_adj.value = 100;
			this.on_scale();
			});
		this.view.layout.set_attribute("rankdir", "BT");
		/*
		this.view.layout.set_attribute("fontsize", "8");
		this.view.layout.set_attribute("margin", "0.4");
		this.view.layout.set_attribute("pad", "0.4");
		*/
		this.view.border_color.parse("#6F4E37");
		this.view.border_color.alpha = 0.5f;
		this.view.shadow.color.parse("#9d8b7c");
		this.view.selection_color.parse("#cb4335");
		this.view.bg_color.parse("#d5d0cc");
	}

	[GtkChild] private unowned Gtk.Adjustment scale_adj;
	[GtkCallback] private void on_scale() {
		this.view.layout.scale_factor = scale_adj.value / 100;
		this.view.queue_resize ();
	}

	[GtkCallback]
	private void pic_clicked (Gtk.Widget btn) {
		i1.paintable = this.view.layout.get_dot_picture();
	}

	[GtkCallback]
	private void remove_selected (Gtk.Widget btn) {
		print("remove_selected\n");
		this.view.layout.remove_selected();
		this.view.queue_draw();
	}

	[GtkCallback]
	private void generate_click (Gtk.Widget btn) {
		print("generate_click\n");
		Gtk.Button new_btn = new Gtk.Button.from_icon_name( icons[ GLib.Random.int_range(0, icons.length) ]);
		new_btn.clicked.connect(this.generate_click);
		this.view.add_node( new_btn );
		this.view.add_edge( btn, new_btn );
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
				? int.max( 0, GLib.Random.int_range(1, 8) )
				: 0;
			widget.margin_top    = margin;
			widget.margin_bottom = margin;
			widget.margin_start  = margin;
			widget.margin_end    = margin;
			// widget.halign = Gtk.Align.CENTER;

			int size = int.max( 50, GLib.Random.int_range(50, 150) );
			widget.set_size_request(size, size);


			this.view.add_node( widget );
			nodes += widget;

		}

		for ( int i = 0; i < n_edges; i ++ ) {
			this.view.add_edge(
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
	}

	public override int command_line (ApplicationCommandLine command_line) {
		// keep the application running until we are done with this commandline
		this.hold ();

		int n_nodes = 1000;
		int n_edges = 1000;
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

