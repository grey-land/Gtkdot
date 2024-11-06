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



	/**
	 * LightLayout layouts widgets as diagrams
	 *
	 * It may be used from any widget that implements `BaseGraph` class,
	 * using `Gtk.Widget.set_layout_manager`. It implements `measure` and `allocate`
	 * functions to assign the position and preferred size to all children, following
	 * GTK [[https://docs.gtk.org/gtk4/class.Widget.html|Geometry Management]].
	 *
	 */
	public class LightLayout : Gtk.LayoutManager {

		/**
		 * Layout Engine to use, "dot" by default.
		 * Other options may be ''neato'', ''sfdp'', ''circo'', ''twopi'', ''patchwork'' ''osage'' ...
		 *
		 * //Please note that even if ''fdp'' is a valid graphviz option it currently breaks the layout
		 * sizing so needs special care//
		 *
		 * Read more about [[https://graphviz.org/docs/layouts/|Layout Engines]].
		 */
		public string layout_engine { get; set; default =
					"dot"
					// "sfdp"
					// "circo"
					// "twopi"
					// "patchwork"
					// "osage"
					; }

		public double minimum_width  { get; set; default=20; }
		public double minimum_height { get; set; default=20; }

		public bool enable_signals { get; set; default=false; }

		public signal void layout_updated ();

		public LightLayout(bool enable_signals = false) {
			this.enable_signals = enable_signals;
		}

		/**
		 * Once rooted, detect widgets missing from graph and add them.
		 *
		 * This is required for widgets initialized through Gtk.Builder
		 */
		protected override void root () {
			BaseGraph parent = this.get_widget() as BaseGraph;
			if ( parent == null ) {
				critical("Expected widget implementing BaseGraph class. Layout might end up in inconsistent state" );
				return;
			}
			Gtk.Widget child = parent.get_first_child ();
			while ( child != null ) {
				if ( ! parent.node_exists( child ) ) {
					parent.add_node( child );
				}
				child = child.get_next_sibling();
			}
		}

		/**
		 * Override create_layout_child to add widget to graph
		 */
		public override Gtk.LayoutChild create_layout_child (Gtk.Widget container, Gtk.Widget child) {
			BaseGraph parent = this.get_widget() as BaseGraph;
			if ( parent != null ) {
				if ( ! parent.node_exists( child ) )
					parent.add_node( child );
			}
			return base.create_layout_child(container, child);
		}

		protected override Gtk.SizeRequestMode get_request_mode (Gtk.Widget widget) {
			return
				Gtk.SizeRequestMode.CONSTANT_SIZE
				// Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH
				;
		}


		/**
		 * Maps child widgets measurements to underlying `Gvc.Graph` diagram.
		 *
		 * It uses `BaseGraph.foreach_node` to iterate through `Gtk.Widget` and `Gvc.Node`
		 * pairs; calculates widget's preferred size and assign it to `Gvc.Node` node
		 * using 'width' and 'height' attributes. If widget is hidden ( or should not
		 * layout for any reason ) it zeros 'width' and 'height' attributes.
		 *
		 * It then processes `Gvc.Graph` diagram where nodes' positions and graph's size
		 * are calculated, and report back `minimum` and `natural` measurement based
		 * on 'bb' graph attribute.
		 *
		 * Keep in mind that edges are not handled here at all.
		 *
		 */
		protected override void measure (Gtk.Widget widget,
										Gtk.Orientation orientation,
										int for_size,
										out int minimum,
										out int natural,
										out int minimum_baseline,
										out int natural_baseline) {
			BaseGraph parent = this.get_widget() as BaseGraph;
			if ( parent == null ) {
				critical("Falls back to default measure implementation");
				base.measure( widget, orientation, for_size,
								out  minimum,
								out  natural,
								out  minimum_baseline,
								out  natural_baseline);
				return;
			}

			unowned Gvc.Graph _graph = parent.get_graph();

			parent.foreach_node( ( _g, child, node )=>{
				if ( child.should_layout() ) {
					Gtk.Requisition req;
					child.get_preferred_size (out req, null );
					node.safe_set("width", "%g".printf(
						points_to_inches(
							req.width // + child.margin_start + child.margin_end
						)
					), "");
					node.safe_set("height", "%g".printf(
						points_to_inches(
							req.height // + child.margin_top + child.margin_bottom
						)
					), "");
				} else {
					node.safe_set("width", "0", "");
					node.safe_set("height", "0", "");
				}
				return false;

			});

			debug("Diagram: %s\n",
				(string) render_diagram(_graph, this.layout_engine, "dot") );

			string bb = _graph.get("bb");

			natural = minimum = ( orientation == Gtk.Orientation.HORIZONTAL )
				? (int) ( get_bb_w( bb ) )
				: (int) ( get_bb_h( bb ) )
				;

			minimum_baseline = natural_baseline = -1; // no baseline support
		}

		/**
		 * Allocates child widgets based on `Gvc.Graph` diagram calculations.
		 *
		 * At first it sets the graph's ''size'' attribute from provided width and
		 * height. Then processes the diagram to calculate the position of the
		 * nodes.
		 *
		 * Once diagram is processed, uses `BaseGraph.foreach_node` to iterate through
		 * `Gtk.Widget` and `Gvc.Node` pairs, and calculates widget's allocation
		 * using node's ''pos'', ''width'' and ''height'' attributes. Nodes' width
		 * and height attributes are already set from `measure` function and not
		 * altered here.
		 *
		 * Keep in mind that this function allocates size only for widgets considered
		 * visible.
		 *
		 */
		public override void allocate (Gtk.Widget widget, int width, int height, int baseline) {

			BaseGraph parent = this.get_widget() as BaseGraph;
			if ( parent == null ) {
				critical("Falls back to default allocate implementation");
				base.allocate( widget, width, height, baseline);
				return;
			}

			unowned Gvc.Graph _graph = parent.get_graph();

			_graph.safe_set("size",
					"%g,%g".printf(
						points_to_inches( (double) width ), points_to_inches( (double) height )
						), "");

			debug("Diagram: %s\n",
				(string) render_diagram(_graph, this.layout_engine, "xdot") );

			parent.foreach_node( ( _g, child, node )=>{

				double x = double.parse( node.get("pos").split(",")[0] );
				double y = double.parse( node.get("pos").split(",")[1] );
				double w = inches_to_points( double.parse( node.get("width") ) );
				double h = inches_to_points( double.parse( node.get("height") ) );

				child.allocate_size (  {
						(int) ( x - ( w / 2 ) ),
						(int) ( y - ( h / 2 ) ),
						(int) w,
						(int) h
					}, baseline );

				return false;
			}, true );

			if ( enable_signals )
				this.layout_updated();
		}

	}

}
