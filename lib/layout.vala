namespace Gtkdot {


	public interface GvcMember : GLib.Object {
		public abstract void set_attribute(string a_n, string a_v);
		public abstract string get_attribute(string a);
	}


	/**
	 * GraphLayout lays out Gtk.Widgets as diagrams using Graphviz.
	 *
	 * All child widgets are wrapped using `GvcGraphNode` and represent
	 * nodes in the result diagram.
	 *
	 * Using `add_edge` will create a `GvcGraphEdge` that connects provided
	 * widgets and represents an edge in the result diagram.
	 *
	 * `GraphLayout`, `GvcGraphNode` and `GvcGraphEdge` implement `GvcMember` interface
	 * which is a wrapper around Gvc.Graph, Gvc.Node, Gvc.Edge internal graphviz structures,
	 * exposing `get_attribute` and `set_attribute` to customize how graphviz is rendered.
	 *
	 * Additionally `GvcGraphEdge` and  `GvcGraphNode` implements `GvcGraphMember` interface
	 * exposing additional functionality such as handling selection flag.
	 *
	 */
	public class GraphLayout : Gtk.LayoutManager, GvcMember {

		public double scale_factor { get; set; default = 1; }

		protected string _layout_engine = "dot";
		protected Gvc.Context _ctx;
		protected Gvc.Graph _graph;

		private uint n_nodes = 0;
		// private double _initial_h = 0;
		// private double _initial_w = 0;

		public Graph graph {
			get { return this.get_widget() as Graph; }
		}

		public GraphLayout(
							string? layout_engine
								// https://graphviz.org/docs/layouts/
								= "dot"
								// = "neato"
								// = "circo"
								//  ...
							, string? title = ""
							, bool directed = true ) {
			this._layout_engine = layout_engine;
			if ( directed )
				this._graph = new Gvc.Graph (title, Gvc.Agdirected);
			else
				this._graph = new Gvc.Graph (title, Gvc.Agundirected);
			this._ctx = new Gvc.Context();
		}

		public signal void layout_processed();
		public signal void member_added(GvcGraphMember member);
		public signal void member_removed(GvcGraphMember member);

		/**
		 * Process internal graphviz diagram and return result.
		 *
		 * @param output_format Graphviz format to use as output, dot|xdot|png|json|...
		 * @return raw data of the rendered diagram.
		 */
		public uint8[] process_diagram( string output_format = "dot" ) {
			uint8[] ret = {};
			this._ctx.layout(this._graph, this._layout_engine);
			this._ctx.render_data(this._graph, output_format, out ret);
			this._ctx.free_layout(this._graph);
			this.layout_processed();
			return ret;
		}

		/*** Returns internal graphviz diagram as Gdk.Texture. */
		public Gdk.Texture get_dot_picture() throws GLib.Error {
			return Gdk.Texture.from_bytes (
						new GLib.Bytes (
							this.process_diagram ("png") ) );
		}

		/*** Get attribute from internal graphviz node */
		public string get_attribute(string a) {
			return this._graph.get(a);
		}

		/*** Set attribute to internal graphviz graph */
		public void set_attribute(string name, string val) {
			this._graph.safe_set(name, val, "");
		}

		/*** Add widget to graph and return the corresponding node
		public GvcGraphNode add_node ( Gtk.Widget widget ) {
			return create_layout_child( this.graph, widget) as GvcGraphNode;
		}
		*/

		/*** Get corresponding node for given widget */
		public GvcGraphNode get_node ( Gtk.Widget widget ) {
			return this.get_layout_child( widget ) as GvcGraphNode;
		}

		/*** Add edge between provided widgets */
		public GvcGraphEdge add_edge( Gtk.Widget from, Gtk.Widget to ) {
			GvcGraphNode _from = this.get_node( from );
			GvcGraphNode _to = this.get_node( to );
			GvcGraphEdge edge = new GvcGraphEdge.new_from_node(
					this._graph.create_edge( _from.node, _to.node ),
					_from, _to );

			this.graph.edges.append(edge);
			this.member_added(edge);
			return edge;
		}

		/*** Get list of edges for given widget */
		public GvcGraphEdge[] get_widget_edges( Gtk.Widget widget ) {
			GvcGraphEdge[] ret = {};
			GvcGraphNode node = this.get_node( widget );
			for ( int i = 0; i < this.graph.edges.n_items; i ++ ) {
				GvcGraphEdge e = this.graph.edges.get_item(i) as GvcGraphEdge;
				if ( e != null && node.name() == e.from || node.name() == e.to )
					ret += e;
			}
			return ret;
		}

		/***
		 * Set selection flag for node/edges that are part of provided selection.
		 *
		 * Keep in mind that edges which are connected to any selected node
		 * will be set as selected regardless if they are selected or not.
		 *
		 */
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

		/*** Removes selected nodes and edges */
		public void remove_selected () {

			for ( uint i = 0; i < this.graph.edges.n_items; i ++ ) {
				GvcGraphEdge e = this.graph.edges.get_item(i) as GvcGraphEdge;
				if ( e != null && e.is_selected() ) {
					print("\tRemove edge ( %s -> %s )\n", e.from, e.to );
					this.graph.edges.remove(i);
					i --;
					this.member_removed(e);
				}
			}

			GvcGraphNode[] to_remove = {};
			Gtk.Widget child;
			GvcGraphNode node;
			for ( child = graph.get_first_child (); child != null; child = child.get_next_sibling() ) {
				node = this.get_node( child );
				if ( node.is_selected() ) {
					to_remove += node;
				}
			}

			foreach ( var n in to_remove ) {
				n.child_widget.unparent();
				this.member_removed(n);
			}
		}

		/*** Validate / Fix nodes and edges once layout is bound to graph */
		protected override void root () {

			// Initialize Edge store
			if ( this.graph.edges == null )
				this.graph.edges = new GLib.ListStore( typeof ( GvcGraphEdge ) );

			// Loop through edges and validate them.
			// This step is important for edges that are added through Gtk.Builder xml
			// as they won't contain Graph's Edge.
			for ( int i = 0; i < this.graph.edges.get_n_items(); i ++ ) {

				var e = this.graph.edges.get_item(i) as GvcGraphEdge;
				if ( e != null ) {
					// Try to fix edge, by detecting from / to widgets and
					// add edge's representation to internal graph.
					if ( e.edge == null && e.from != null && e.to != null ) {
						GvcGraphNode? _from = null;
						GvcGraphNode? _to = null;
						Gtk.Widget child;
						GvcGraphNode _n;
						for ( child = this.graph.get_first_child (); child != null; child = child.get_next_sibling() ) {
							_n = this.get_node( child );
							if ( _n == null ) continue;
							if ( _from != null && _to != null ) {
								e.edge = this._graph.create_edge( _from.node, _to.node );
								// Similarly to Edge construction binding is disabled.
								//_from.child_widget.bind_property ( "visible",
								//
								//	e, "visible", GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.DEFAULT );
								//_to.child_widget.bind_property ("visible",
								//	e, "visible", GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.DEFAULT );
								break;
							}
							if ( e.from == child.get_id() ) _from = _n;
							if ( e.to == child.get_id() ) _to = _n;
						}
					}
					// If edge is valid continue to next one
					if ( e.edge != null && e.from != null && e.to != null )
						continue;
				}
				// If this point is reached means that the edge is invalid so
				// we are removing it from store.
				critical("! Invalid Edge detected %d, will be removed", i);
				this.graph.edges.remove(i);
				i --;
			}
		}

		protected override Gtk.SizeRequestMode get_request_mode (Gtk.Widget widget) {
			return Gtk.SizeRequestMode.CONSTANT_SIZE;
		}

		public override Gtk.LayoutChild create_layout_child (Gtk.Widget container, Gtk.Widget child) {
			string child_id = "n%d".printf( (int) n_nodes );
			n_nodes ++;
			Gvc.Node n = this._graph.create_node( child_id );
			return new GvcGraphNode(this, child, n);
		}

		protected override void measure (Gtk.Widget widget,
										Gtk.Orientation orientation,
										int for_size,
										out int minimum,
										out int natural,
										out int minimum_baseline,
										out int natural_baseline) {

			// Set preferred size for nodes
			this.foreach_member( ( member ) => {
					Gtk.Widget child = member.get_object() as Gtk.Widget;
					Gtk.Requisition req;
					child.get_preferred_size (out req, null  );
					member.set_attribute("width",
							"%g".printf( to_inches(
									req.width  // + child.margin_start + child.margin_end
								* this.scale_factor ) )
						);
					member.set_attribute("height",
							"%g".printf( to_inches(
									req.height // + child.margin_top + child.margin_bottom
								* this.scale_factor ) )
						);
					return false;
				}, GvcGraphMemberKind.NODE );

			// Compute layout
			debug( "MEASURE DIAGRAM\n%s\n", (string)
				this.process_diagram("dot")
			);

			// Parse bounding box computed from graphviz and
			// assign width and height
			string bb = this._graph.get("bb");
			double w = 0;
			double h = 0;

			debug("Graph BB: %s\n", bb);
			if ( bb != null ) {
				string _sep;
				if ( bb.split(",").length > 0 ) _sep = ",";
				else _sep = " ";
				w = double.max( w, double.parse( bb.split(_sep)[2] ) );
				h = double.max( h, double.parse( bb.split(_sep)[3] ) );
				// if ( _initial_h == 0 ) _initial_h = h;
				// if ( _initial_w == 0 ) _initial_w = w;
			} else {
				warning("Failed to detect graph size");
			}

			// Propagate width and height measurements computed from graphviz
			if ( orientation == Gtk.Orientation.HORIZONTAL ) //  Width
				minimum = (int) ( w
					// * this.scale_factor
					)  + ( (int) graph.stroke.get_line_width() * 2 );

			else // Height
				minimum = (int) ( h
					// * this.scale_factor
					)  + ( (int) graph.stroke.get_line_width() * 2 );

			natural = minimum;
			minimum_baseline = natural_baseline= -1;
		}

		public override void allocate (Gtk.Widget widget, int width, int height, int baseline) {

			// Size | Viewport does size assignment have an effect here ?
			// TODO: Need to check it.
			//
			this.set_attribute("size", "%g,%g".printf( to_inches( (double) width ), to_inches( (double) height ) ));
			// this.set_attribute("viewport", "%d,%d,%g".printf( width, height, graph.get_scale_value() ) );

			// Process diagram
			debug( "ALLOCATED DIAGRAM\n%s\n", (string)
				this.process_diagram("xdot")
			);

			// Loop through graph members
			this.foreach_member( ( member ) => {

				// Process member's allocation. This step is required for
				// both nodes and edges as it computes the bounding box
				// that is used for selection bounds.
				Gtk.Allocation alloc = member.get_allocation(true);

				// For Nodes
				if ( member.get_kind() == GvcGraphMemberKind.NODE ) {

					// get underline widget
					Gtk.Widget child = member.get_object() as Gtk.Widget;

					// apply stroke
					int off = (int) graph.stroke.get_line_width() ;
					alloc.x += off ; //- child.margin_start;
					alloc.y += off ; // - child.margin_top;
					alloc.width -= (off * 2)  ; // + child.margin_start + child.margin_end;
					alloc.height -= (off * 2) ; // + child.margin_top + child.margin_bottom ;

					// Gtk.Widget* ptr = child;
					// debug( "\t\t[%s] (%p) Allocate Node : x=%g y=%g size=(%g, %g)\n",
					//	member.name(), ptr, alloc.x, alloc.y, alloc.width, alloc.height );

					// allocate child
					child.allocate_size ( alloc, -1 );
				}

				return false;
			});
		}

		/**
		 * Iterate through graph members ( nodes & edges )
		 *
		 * @param func handle member and return `true` to stop iteration or `false` to continue.
		 * @param kind set member kind to filter nodes or edges, or `null` to handle everything.
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
				for ( int i = 0; i < this.graph.edges.n_items; i ++ ) {
					GvcGraphEdge e = this.graph.edges.get_item(i) as GvcGraphEdge;
					if ( e != null && func( e ) )
						return;
				}
			}

		}

	}

}
