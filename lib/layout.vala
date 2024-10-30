namespace Gtkdot {

	public class GraphLayout : Gtk.LayoutManager {

		protected string _graph_format = "dot";
		protected string _graph_format_ext = "xdot";

		protected Gvc.Context _ctx;
		protected Gvc.Graph _graph;
		protected GLib.List<GvcGraphEdge> _edges;

		public Graph graph {
			get { return this.get_widget() as Graph; }
		}

		public GraphLayout( string? title = ""
							, string? format = "dot" // | neato | ...
							, string? ext = "xdot" ) {
			this._graph_format = format;
			this._graph_format_ext = ext;
			this._graph = new Gvc.Graph (title, Gvc.Agdirected);
			this._ctx = new Gvc.Context();
		}

		public void set_defaults() {
			// Set dpi. Propaply doesn't affect anything.
			this.set_attribute( "dpi",
				"%g".printf(
					(double) this.graph.get_settings().gtk_xft_dpi / 1024 ) );
		}

		public void set_attribute(string name, string val) {
			this._graph.safe_set(name, val, "");
		}

		public unowned GLib.List<GvcGraphEdge> get_edges () {
			return this._edges;
		}

		public GvcGraphNode add_node ( Gtk.Widget widget ) {
			return create_layout_child( this.graph, widget) as GvcGraphNode;
		}

		public GvcGraphNode get_node ( Gtk.Widget widget ) {
			return this.get_layout_child( widget ) as GvcGraphNode;
		}

		public void add_edge( Gtk.Widget from, Gtk.Widget to ) {
			GvcGraphNode _from = this.get_node( from );
			GvcGraphNode _to = this.get_node( to );
			GvcGraphEdge edge = new GvcGraphEdge.new_from_node(
					this._graph.create_edge( _from.node, _to.node ),
					_from, _to );
			this._edges.append(edge);
		}

		public GvcGraphEdge[] get_widget_edges( Gtk.Widget widget ) {
			GvcGraphEdge[] ret = {};
			GvcGraphNode node = this.get_node( widget );
			for ( int i = 0; i < this._edges.length(); i ++ ) {
				GvcGraphEdge e = this._edges.nth_data(i);
				if ( node.name() == e.from || node.name() == e.to )
					ret += e;
			}
			return ret;
		}


		public void apply_selection (Graphene.Rect selection) {

			string[] ns = {};

			// once selection finished, update
			// graph member `selected` flag
			this.foreach_member( ( member ) => {

				member.set_selected(
					member.contains_selection(selection) );

				GvcGraphNode n = member as GvcGraphNode;
				if ( n.is_selected() )
					ns += n.name();

				return false;
			}, GvcGraphMemberKind.NODE);

			this.foreach_member( ( member ) => {

				member.set_selected(
					member.contains_selection(selection) );

				GvcGraphEdge e = member as GvcGraphEdge;
				if ( ! e.is_selected() ) {
					foreach ( var n in ns ) {
						if ( e.from == n || e.to == n )
							e.set_selected(true);
					}
				}

				return false;
			}, GvcGraphMemberKind.EDGE);
		}

		public void remove_selected () {

			for ( uint i = 0; i < this._edges.length(); i ++ ) {
				GvcGraphEdge e = this._edges.nth_data(i);
				if ( e.is_selected() ) {
					this._edges.remove(e);
					print("\tRemove edge ( %s -> %s )\n", e.from, e.to );
					i --;
				}
			}

			Gtk.Widget[] to_remove = {};
			Gtk.Widget child;
			GvcGraphNode node;
			for ( child = graph.get_first_child (); child != null; child = child.get_next_sibling() ) {
				node = this.get_node( child );
				if ( node.is_selected() ) {
					to_remove += node.child_widget;
				}
			}

			foreach ( var w in to_remove )
				w.unparent();
		}


		protected override Gtk.SizeRequestMode get_request_mode (Gtk.Widget widget) {
			return Gtk.SizeRequestMode.CONSTANT_SIZE;
		}

		public override Gtk.LayoutChild create_layout_child (Gtk.Widget container, Gtk.Widget child) {
			Gtk.Widget* ptr = child;
			Gvc.Node n = this._graph.create_node( "%p".printf( ptr ).substring(-4, 4) );
			return new GvcGraphNode(this, child, n);
		}

		protected override void measure (Gtk.Widget widget,
										Gtk.Orientation orientation,
										int for_size,
										out int minimum,
										out int natural,
										out int minimum_baseline,
										out int natural_baseline) {

			// assign default size
			double w = double.max( (double) widget.get_width(), (double) default_child_width );
			double h = double.max( (double) widget.get_height(), (double) default_child_height );
			this._graph.safe_set("size", "%g,%g\\!".printf( to_inches(w), to_inches(h) ), "");

			// Compute layout
			uint8[] diagram;
			this._ctx.layout(this._graph, this._graph_format);
			this._ctx.render_data(this._graph, "dot", out diagram);
			this._ctx.free_layout(this._graph);
			debug( "MEASURE DIAGRAM\n%s\n", (string) diagram );

			// Parse bounding box
			string bb = this._graph.get("bb");
			debug("Graph BB: %s\n", bb);
			if ( bb != null ) {
				string _sep;
				if ( bb.split(",").length > 0 ) _sep = ",";
				else _sep = " ";
				w = double.max( w, double.parse( bb.split(_sep)[2] ) );
				h = double.max( h, double.parse( bb.split(_sep)[3] ) );
			} else {
				warning("Failed to detect graph size");
			}

			// Assign measurements using bounding box
			if ( orientation == Gtk.Orientation.HORIZONTAL )
				//  Width computed from graphviz
				minimum = natural = (int) w;
			else
				// Height computed from graphviz
				minimum = natural = (int) h;

			minimum_baseline = natural_baseline= -1;
		}

		public override void allocate (Gtk.Widget widget, int width, int height, int baseline) {

			// Size | Viewport doesn't alter the graph, why is this happening ?
			//
			// this.set_attribute("size", "%g,%g\\!".printf( to_inches( (double) width ), to_inches( (double) height ) ));
			// this.set_attribute("viewport", "%d,%d,%d".printf( width, height, widget.scale_factor ) );
			width += graph.margin_start + graph.margin_end;
			height += graph.margin_top + graph.margin_bottom;

			// Process diagram
			uint8[] diagram;
			this._ctx.layout(this._graph, this._graph_format);
			this._ctx.render_data(this._graph, this._graph_format_ext, out diagram);
			this._ctx.free_layout(this._graph);
			debug( "ALLOCATED DIAGRAM\n%s\n", (string) diagram );

			Gtk.Widget child;
			GvcGraphNode node;
			for ( child = graph.get_first_child (); child != null; child = child.get_next_sibling() ) {

				node = this.get_node( child );

				Gtk.Allocation alloc = node.get_allocation(true);

				int soff = (int) graph.stroke.get_line_width();
				alloc.x += soff;
				alloc.y += soff;
				alloc.width -= soff * 2;
				alloc.height -= soff * 2;
				debug( "\t[%s] Allocate Node : x=%g y=%g size=(%g, %g)",
					node.name(), alloc.x, alloc.y, alloc.width, alloc.height );

				child.allocate_size ( alloc, -1 );
			}

			foreach ( var e in this.get_edges() ) {
				e.get_allocation(true);
			}

		}

		/**
		 * Iterate through graph nodes (nodes/edges)
		 *
		 * @param func handle member and return `true` to stop iteration or `false` to continue.
		 * @param kind set member kind to handle only nodes or edges, or `null` to handle everything.
		 */
		public void foreach_member( DelegateMember func, GvcGraphMemberKind? kind = null ) {

			if ( kind == null || kind == GvcGraphMemberKind.NODE ) {
				Gtk.Widget child;
				for ( child = graph.get_first_child (); child != null; child = child.get_next_sibling() ) {
					if ( func( this.get_node(child) ) )
						return;
				}
			}

			if ( kind == null || kind == GvcGraphMemberKind.EDGE ) {
				for ( int i = 0; i < this._edges.length(); i ++ ) {
					if ( func( this._edges.nth_data(i) ) )
						return;
				}
			}

		}

	}

}
