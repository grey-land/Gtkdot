/* application.vala
 *
 * Copyright 2024 @grey-land
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

	private int n_nodes = 0;

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
			{ "dot-layout", this.set_dot_layout },
			{ "neato-layout", this.set_neato_layout },
			{ "sfdp-layout", this.set_sfdp_layout },
			{ "circo-layout", this.set_circo_layout },
			{ "twopi-layout", this.set_twopi_layout },
		}, this);

		// this.get_settings().gtk_application_prefer_dark_theme = true;
		Gtk.CssProvider cssp = new Gtk.CssProvider();
		cssp.load_from_string("""
			/* Graph */
			.graph {
				padding: 10px;
				/* use default gtk background */
				background: @content_view_bg;
			}
			/* add color to selection rect */
			.graph:active {
				color: @theme_selected_bg_color;
			}
			/* revert changes color to child widgers */
			.graph:active * {
				color: @theme_text_color;
			}

			/* Edge */
			/* default edge style */
			.edge, .graph:active .edge {
				color: @unfocused_insensitive_color;
				filter: drop-shadow( 0px  1px 1px #929292 );
			}

			/* selected edge style */
			.edge:selected, .graph:active  .edge:selected {
				color: @theme_selected_bg_color;
				filter: drop-shadow( 0px  1px 1px @theme_fg_color );
			}


			/* Node */
			/* default node style */
			.node { box-shadow: 0 -2px 1px #929292 inset; }

			/* selected node style */
			.node:selected {
				color: @theme_text_color;
				box-shadow: 0 -2px 2px @theme_selected_bg_color inset;
				border: 1px solid @theme_selected_bg_color;
			}

			/* Disable default focus outline */
			.node:focus,
			.node:focus-within,
			.node:focus-visible,
			.node:checked {
				outline: none;
			}

			.vhandle {
				background:  @unfocused_insensitive_color;
			}
			.vhandle:active {
				background:  @theme_unfocused_fg_color;
			}
			""");

		Gtk.StyleContext.add_provider_for_display(
			this.get_display(),
			cssp,
			Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
			//Gtk.STYLE_PROVIDER_PRIORITY_USER
		);


		SimpleEdge.stroke.set_line_width(1.5f);
		// SimpleEdge.stroke.set_dash  ({8, 9});
		// SimpleEdge.stroke.set_dash_offset(3);

		this.view.enable_selection();

		this.view.graph.safe_set("rankdir", "LR", "" );
		this.view.graph.safe_set("ratio", "compress", "" );
		// this.view.graph.safe_set("ratio", "expand", "" );
		this.view.graph.safe_set("overlap", "false", "" );
		// this.view.graph.safe_set("mindist", "0.1", "" );

	}

	private void set_layout(string engine){
		this.view.layout.layout_engine = engine;
		this.view.layout.clean_layout();
		this.view.layout.layout_changed ();
	}

	private void set_dot_layout()   { this.set_layout("dot"); }
	private void set_neato_layout() { this.set_layout("neato"); }
	private void set_sfdp_layout()  { this.set_layout("sfdp");  }
	private void set_circo_layout() { this.set_layout("circo"); }
	private void set_twopi_layout() { this.set_layout("twopi"); }

	private void select_all () {
		this.view.select_all();
	}

	[GtkCallback]
	private void expander_toggled (Gtk.ToggleButton btn) {
		foreach ( string k in this.view.members.get_keys() ) {
			Gtk.Widget child = this.view.get_member(k);
			if ( "vhandle" in child.get_css_classes() ) {
				this.view.set_visibility(child, btn.get_active() );
			}
		}
		if ( btn.get_active() )
			btn.icon_name = "view-fullscreen-symbolic";
		else
			btn.icon_name = "view-restore-symbolic";
	}

	[GtkCallback]
	private void remove_selected () {
		this.view.remove_selected();
	}

	[GtkCallback]
	private void generate_click (Gtk.Button btn) {
		Gtk.Button new_btn = generate_button();
		new_btn.set_size_request(50, 30);
		this.view.add_full_node( new_btn );
		this.view.add_full_edge( btn, new_btn );
		new_btn.grab_focus();
	}

	private void set_visibility (Gtk.Button btn) {
		this.view.set_visibility(btn, ! btn.visible );
	}



	public Gtk.Button generate_button() {
		Gtk.Button widget;
		if ( n_nodes % 3 == 0 ) {
			widget = new Gtk.Button.with_label("%d".printf( n_nodes ));
			widget.clicked.connect(this.set_visibility);
			widget.add_css_class("vhandle");
		} else {
			widget = new Gtk.Button.from_icon_name (
						icons[ GLib.Random.int_range(0, icons.length) ] );
			widget.clicked.connect(this.generate_click);
			widget.add_css_class("ghandle");
		}
		n_nodes ++;
		return widget;
	}

	public void generate_widgets(int n_nodes, int n_edges) {
		Gtk.Button[] nodes = {};
		Gtk.Button widget;

		for ( int i = 0; i < n_nodes; i ++ ) {
			widget = generate_button();
			widget.set_size_request(50, 50);
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

		int n_nodes = 0;
		int n_edges = 0;
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

