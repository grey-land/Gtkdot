
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
