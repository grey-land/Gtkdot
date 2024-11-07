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
	 * LightGraph is the simplest implementation of `BaseGraph`.
	 *
	 * It uses `LightLayout` to layout widgets using graphviz and parses the `xdot` graphviz's
	 * extension to render edges in addition to the widgets. It holds a `Gvc.Graph` where nodes
	 * and edges are added without keeping any reference to them. This is enough for simple
	 * diagrams that don't need to alter their contents, and for cases where hundreds or thousands of
	 * nodes and edges are required.
	 *
	 * To better understand how it works have a look under
	 * - `LightLayout.measure`
	 * - `LightLayout.allocate`
	 * - `BaseGraph.foreach_node`
	 *
	 * Use `add_node` to add widgets as nodes and `add_edge` to connect widgets.
	 * Set `stroke` variable to change stroking styling.
	 * Set `draw_node_borders` boolean to true to draw borders around widget nodes.
	 *
	 * Use `get_graph` to get the underline `Gvc.Graph` object to customize or query it. Do not
	 * add nodes or edges directly into it as it will break the sequence of nodes and edges.
	 *
	 */
	public class LightGraph : BaseGraph {

		public Gsk.Stroke stroke {get;set;}
		public bool draw_node_borders { get; set; default=false;}

		public LightLayout layout {
			get { return layout_manager as LightLayout; }
		}

		construct {

			// graph
			this._graph = new Gvc.Graph (
							this.graph_id != null ? this.graph_id : get_widget_id(this),
							this.directed ? Gvc.Agdirected : Gvc.Agundirected );
			// layout
			this.set_layout_manager( new LightLayout() );

			// styles
			this.stroke = new Gsk.Stroke(1);
			this.add_css_class ("graph");
		}

		/**
		 * Render edges and nodes.
		 *
		 * Extends the default `Gtk.Widget.snapshot` implementation to draw edges
		 * and ( optionally ) borders around child widgets.
		 */
		public override void snapshot( Gtk.Snapshot snapshot ) {

			// Draw nodes
			base.snapshot(snapshot);

			string[] hidden_node_names = {};
			double w, h;
			Gvc.Edge e;
			Gsk.Path? path = null;
			Gdk.RGBA color = this.get_color();

			// First iterate through node widgets and collect all invisible
			// nodes under `hidden_node_names`. Additionally draw node
			// borders if `draw_node_borders` is set to true.
			Gtk.Widget child = this.get_first_child ();
			Gvc.Node node = this._graph.get_first_node();
			while ( child != null && node != null) {

				if ( ! child.should_layout() ) {
					hidden_node_names += node.name();
					node = this._graph.get_next_node(node);
					child = child.get_next_sibling();
					continue;
				}
				if ( draw_node_borders ) {
					// Draw node border
					w = inches_to_points( double.parse( node.get("width") ) );
					h = inches_to_points( double.parse( node.get("height") ) );
					snapshot.append_border(
						Gsk.RoundedRect().init_from_rect(
						Graphene.Rect().init (
							(float) ( double.parse( node.get("pos").split(",")[0] ) - w / 2 ),
							(float) ( double.parse( node.get("pos").split(",")[1] ) - h / 2 ),
							(float) w,
							(float) h
						), 6),
						{
							stroke.get_line_width (),
							stroke.get_line_width (),
							stroke.get_line_width (),
							stroke.get_line_width () },
						{ color, color, color, color } );
				}

				node = this._graph.get_next_node(node);
				child = child.get_next_sibling();
			}

			// Iterate through graph nodes, and their edges skipping
			// invisible nodes or edges that connect at least one
			// invisible node.
			for ( node = this._graph.get_first_node(); node != null;
					node = this._graph.get_next_node(node) ) {

				// Skip hidden nodes
				if ( node.name() in hidden_node_names )
					continue;

				// Loop through node edges
				for ( e = this._graph.get_first_edge_out(node); e != null; e = this._graph.get_next_edge_out(e) ) {

					// If edge's head or tail points to a hidden node
					if ( ! ( e.head().name() in hidden_node_names /* || e.tail().name() in hidden_node_names */ ) ) {
						string[] xdots = {
							e.get("_draw_"),
							e.get("_hdraw_"),
							e.get("_tdraw_")
						};
						// print( "\t\tedge [%s] (label: %s)\n", e.name(), e.get("label") );
						for ( int x = 0; x < xdots.length; x ++ ) {
							if ( xdots[x] == null )
								continue;
							// debug( "\t\txdot: [%s]\n", xdots[x] );
							parse_xdot(xdots[x], out path);
							if ( path != null && ! path.is_empty() ) {
								snapshot.append_stroke (path, stroke, color );
								if ( path.is_closed() )
									snapshot.append_fill (path, Gsk.FillRule.WINDING , color );
							}
						}
					}

				}

			}

		}

	}

}
