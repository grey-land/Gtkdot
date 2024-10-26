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

	public Window (Gtk.Application app) {
		Object (application: app);

		// this.view = new GraphView();
		// var s = new Gtk.ScrolledWindow();
		// s.set_child(this.view);
		// this.set_child(s);

		this.generate_widgets(20, 50);

	}


	private void generate_widgets( int nodes, int edges ) {

		string[] icons = {
			"dialog-password-symbolic",
			"non-starred-symbolic",
			"security-medium-symbolic",
			"emblem-system-symbolic",
			"user-trash-symbolic",
			"tab-new-symbolic",
			"weather-few-clouds-symbolic",
			"weather-showers-symbolic"
		};

		for ( int i = 0; i < nodes; i++ ) {
			if ( i % 2 == 0 ) {
				var widget = new Gtk.Image.from_icon_name(
									icons[ GLib.Random.int_range(0, icons.length) ]
								);
				//int size = int.max( 50, GLib.Random.int_range(50, 100) );
				//widget.set_size_request(size, size);
				view.add_node( widget );

			} else {
				view.add_node(
					new Gtk.Button.with_label("%d button".printf(i))
				);
			}
		}

		for ( int i = 0; i < edges; i++ ) {
			view.add_edge(
				(int) GLib.Random.int_range(0, nodes),
				(int) GLib.Random.int_range(0, nodes)
			);
		}

		// foreach
	}
}
