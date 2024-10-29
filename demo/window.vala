/* window.vala
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

[GtkTemplate (ui = "/io/gitlab/vgmkr/dot/ui/window.ui")]
public class Gtkdot.Window : Gtk.ApplicationWindow {

	[GtkChild]
	private unowned Gtkdot.GraphView view;

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

	public Window (Gtk.Application app) {
		Object (application: app);

		view.border_color.parse("#6F4E37");
		view.shadow.color.parse("#9d8b7c");

		view.enable_selection();
		view.selection_color.parse("#cb4335");

		view.margin_top    = 20;
		view.margin_bottom = 20;
		view.margin_start  = 20;
		view.margin_end    = 20;
		// this.generate_widgets(120, 220);
		this.generate_widgets(5, 5);
		// this.generate_widgets(10, 10);
	}

	[GtkCallback]
	private void debug (Gtk.Widget btn) {
		view.layout.nodes.@foreach( (k, v) => {
			Node node = v;
			print("Node %d:%d\n", (int) k, (int) node.id );
		});
		print("\n");

		for ( int i = 0; i < view.layout.edges.length(); i ++ ) {
			Edge e = view.layout.edges.nth_data(i);
			print("Edge %d -> %d\n", (int) e.start, (int) e.end );
		}

	}

	[GtkCallback]
	private void remove_selected (Gtk.Widget btn) {
		view.remove_selected();
	}

	[GtkCallback]
	private void btn_clicked (Gtk.Widget btn) {

		Gtk.Button new_btn = new Gtk.Button.from_icon_name (
						icons[ GLib.Random.int_range(0, icons.length) ]);
		new_btn.clicked.connect(this.btn_clicked);

		uint current = view.get_member_id_for_widget( btn );
		print( "Clicked => %d\n", (int) current );

		uint n = view.add_node(new_btn);
		print( "Added node => %d\n", (int) n );

		uint	 e = view.add_edge( current, n );
		print( "Added edge => %d\n", (int) e );

	}

	private void generate_widgets( int nodes, int edges ) {

		uint[] wids = {};

		for ( int i = 0; i < nodes; i++ ) {
			Gtk.Button widget;

			if ( i % 2 == 0 ) {
				widget = new Gtk.Button.from_icon_name (
								icons[ GLib.Random.int_range(0, icons.length) ] );
			} else {
				widget = new Gtk.Button.with_label("%d button".printf(i));
			}

			widget.clicked.connect(this.btn_clicked);

			int size = int.max( 50, GLib.Random.int_range(50, 150) );
			widget.set_size_request(size, size);
			if ( i % 3 == 0 ) {
				int margin = int.max( 0, GLib.Random.int_range(10, 30) );
				widget.margin_top    = margin;
				widget.margin_bottom = margin;
				widget.margin_start  = margin;
				widget.margin_end    = margin;
			}
			/*
			*/

			// wids += view.add_node( widget, "color=\"slateblue\"" );
			wids += view.add_node( widget
								, "color=\"#ada9a5\""
								);


		}

		for ( int i = 0; i < edges; i++ ) {

			view.add_edge(
				wids [ (int) GLib.Random.int_range(0, nodes) ],
				wids [ (int) GLib.Random.int_range(0, nodes) ]
				// , " fontcolor=\"slateblue\" color=\"slateblue\" "
				, "fontcolor=\"#ada9a5\" color=\"#ada9a5\""
			);
		}

		// foreach
	}
}
