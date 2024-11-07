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
namespace Gtkdot {


	/**
	 * SimpleLayout extexts LightLayout managing both nodes and edges as Gtk.Widgets.
	 *
	 * It pairs with `SimpleGraph` widget laying out it's children.
	 */
	public class SimpleLayout : LightLayout {

		public SimpleGraph parent {
			get { return this.get_widget() as SimpleGraph; }
		}

		/**
		 * Detect orphan widgets and import them to Gvc.Graph.
		 *
		 * This is needed for widgets defined in Gtk.Buildable '.ui' as
		 * they are don't use `SimpleGraph.add_full_node` or `SimpleGraph.add_full_edge`
		 * functionality.
		 */
		protected override void root () {
			if ( this.parent == null ) {
				critical("SimpleLayout should contain SimpleGraph widget." );
				return;
			}
			Gtk.Widget child = this.parent.get_first_child ();
			while ( child != null ) {
				switch ( SimpleGraph.get_kind(child) ) {
					case GraphMemberKind.NODE:
						this.parent.add_full_node(child);
						break;
					default:
						this.parent.connect_edge( child as SimpleEdge );
						break;
				}
				child = child.get_next_sibling();
			}
		}

		/*** Get SimpleMember for given widget */
		public SimpleMember get_member ( Gtk.Widget widget ) {
			return this.get_layout_child( widget ) as SimpleMember;
		}

		public override Gtk.LayoutChild create_layout_child (Gtk.Widget container, Gtk.Widget child) {
			return new SimpleMember(this, child);
		}

		public void clean_layout () {
			unowned Gvc.Graph _graph = this.parent.get_graph();
			Gvc.Node? n = null;
			Gvc.Edge? e = null;
			for ( n = _graph.get_first_node(); n != null; n = _graph.get_next_node(n) ) {
				n.safe_set("_draw_", "", "");
				n.safe_set("pos", "", "");
				for (e = _graph.get_first_edge_out(n); e != null; e = _graph.get_next_edge_out(e)) {
					e.safe_set("_draw_", "", "");
					e.safe_set("pos", "", "");
				}
			}
		}

		/**
		 * Allocate size for all children widgets (both nodes and edges)
		 */
		public override void allocate (Gtk.Widget widget, int width, int height, int baseline) {

			unowned Gvc.Graph _graph = this.parent.get_graph();

			_graph.safe_set("_draw_", "", ""); // clean up graph xdot attribute
			_graph.safe_set("size",
					"%g,%g".printf(
						points_to_inches( (double) width ), points_to_inches( (double) height )
						), "");

			debug("Diagram: %s\n",
				(string) render_diagram(_graph, this.layout_engine, "xdot") );

			SimpleMember member;
			Gvc.Node? n = null;
			Gvc.Edge? e = null;

			// Iterate through Gvc.Graph nodes
			for ( n = _graph.get_first_node(); n != null; n = _graph.get_next_node(n) ) {

				// Get Gtk.Widget corresponding to Gvc.Node and parse it's shape and
				// allocate appropriate size
				member = this.get_member( this.parent.get_member( n.name() ) );
				member.parse_xdot_attrs({ n.get("_draw_") });
				member.child_widget.allocate_size( member.compute_allocation(), baseline );

				// Iterate through outgoing Gvc.Edges for given node
				for (e = _graph.get_first_edge_out(n); e != null; e = _graph.get_next_edge_out(e)) {

					// Get Gtk.Widget corresponding to Gvc.Node and parse it's shape and
					// allocate appropriate size
					member = this.get_member( this.parent.get_member( e.name() ) );
					member.parse_xdot_attrs({ e.get("_draw_"), e.get("_tdraw_"), e.get("_hdraw_")  });
					member.child_widget.allocate_size( member.compute_allocation(), baseline );

					// Force redraw all edges as in any new allocation
					// edge positions and sizes change.
					member.child_widget.queue_draw();
				}

			}

			if ( enable_signals )
				this.layout_updated();

		}

	}


}
