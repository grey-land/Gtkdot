namespace Gtkdot {


	/**
	 * Edge class contain information about connected nodes.
	 *
	 * Implements `IGraphMember` interface.
	 */
	protected class Edge : GLib.Object, IGraphMember {

		public uint start { get; construct; }
		public uint end { get; construct; }
	 	public string extra { get; set; default = ""; }

		private Rendering[] _renderings = {};
		private bool _selected = false;
		private Gtk.Allocation? _allocation = null;

		public Edge.new_from_id( uint start, uint end ) {
			GLib.Object(start: start, end: end);
		}

		public GraphMemberKind get_kind () {
			return GraphMemberKind.EDGE;
		}

		public void set_selected(bool val) {
			this._selected = val;
		}

		public bool is_selected() {
			return this._selected;
		}

		public void set_renderings(Rendering[] val) {
			this._renderings = val;
			// when new renderings are assigned,
			// then we null _allocation to re-calculate it
			this._allocation = null;
		}

		public Rendering[] get_renderings() {
			return _renderings;
		}

		public string get_label() {
			return "(%d>>%d)".printf( (int) this.start, (int) this.end );
		}

		public Gtk.Allocation get_allocation() {

			// If allocation is not assigned
			if ( this._allocation == null ) {

				// initialize allocation with default values
				this._allocation = {
						0, 0, default_child_width, default_child_height
					};

				// Build a path that contains all rendering sub-paths.
				Gsk.PathBuilder pb = new Gsk.PathBuilder();
				foreach ( var r in this.get_renderings() ) {
					pb.add_path(r.path);
				}

				// Get bounds of the resulted path
				Graphene.Rect bounds;
				pb.to_path().get_bounds(out bounds);

				// and assign allocation from bounds
				this._allocation = {
					(int) bounds.origin.x, (int) bounds.origin.y,
					(int) bounds.size.width, (int) bounds.size.height
				};
			}

			return this._allocation;
		}

	}


	/**
	 *
	 */
	public class Node: Gtk.LayoutChild, IGraphMember {

		public uint id { get; construct; }
		public string extra { get; set; default = ""; }

		private Rendering[] _renderings = {};
		private bool _selected = false;
		private Gtk.Allocation? _allocation = null;

		public Node (Gtk.LayoutManager manager, Gtk.Widget child, uint id) {
			GLib.Object(
				layout_manager: manager,
				child_widget: child,
				id: id
			);
		}

		public GraphMemberKind get_kind () {
			return GraphMemberKind.NODE;
		}

		public void set_renderings(Rendering[] val) {
			this._renderings = val;
			this._allocation = null;
		}
		public Rendering[] get_renderings() {
			return this._renderings;
		}

		public void set_selected(bool val) {
			this._selected = val;
		}

		public bool is_selected() {
			return this._selected;
		}

		public Gtk.Allocation get_allocation() {

			// If allocation is not assigned
			if ( this._allocation == null ) {

				// initialize allocation with default values
				this._allocation = {
						0, 0, default_child_width, default_child_height
					};

				// Get main _draw_ rendering and set `_allocation` to it's path bounds
				foreach ( var r in this.get_renderings() ) {
					if ( r.x_dot == "_draw_" ) {
						Graphene.Rect bounds;
						if ( r.path.get_bounds(out bounds) ) {
							this._allocation = {
										(int) bounds.origin.x    + default_margin,
										(int) bounds.origin.y    + default_margin,
										(int) bounds.size.width  - ( default_margin * 2 ),
										(int) bounds.size.height - ( default_margin * 2 )
							};
						}
						break;
					}
				}
			}

			return this._allocation;
		}

		public Gsk.RoundedRect get_rounded_border( float stroke = 1, float radius = 0) {
			return Gsk.RoundedRect().init_from_rect (
					Graphene.Rect().init(
						(float) this._allocation.x - stroke,
						(float) this._allocation.y - stroke,
						(float) this._allocation.width + (stroke * 2),
						(float) this._allocation.height + (stroke * 2)
					), radius);
		}

	}


	public class GraphLayoutManager : Gtk.LayoutManager {

		public Rendering[] renderings;

		private uint n_nodes = 0;
		public HashTable<uint, Node*> nodes = new HashTable<uint, Node*> (direct_hash, direct_equal);
		public GLib.List<Edge> edges;

		public GraphLayoutManager() {
			this.edges = new GLib.List<Edge>();
		}

		public Node get_member_from_widget ( Gtk.Widget widget ) {
			return this.get_layout_child( widget ) as Node;
		}

		public override Gtk.LayoutChild create_layout_child (Gtk.Widget container, Gtk.Widget child) {
			Node member = new Node(this, child, n_nodes );
			Node* ptr = member;
			nodes.insert( n_nodes, ptr);
			n_nodes ++;
			return member;
		}

		protected override Gtk.SizeRequestMode get_request_mode (Gtk.Widget widget) {
			return Gtk.SizeRequestMode.CONSTANT_SIZE;
		}

		double to_inches( double val ) {
			return val / 25.4 / 3;
		}

		/*

		double from_inches( double val ) {
			return val * 25.4 * 3;
		}

		protected void parse_margin(Gtk.Widget widget, string margin) {
			double margin_x = 0;
			double margin_y = 0;
			// Margin for X axis computed from graphviz
			margin_x = margin != null && margin.split(",").length == 2
						? from_inches( double.parse(margin.split(",")[0]) )
						: 0;
			// Margin for Y axis computed from graphviz
			margin_y = margin != null && margin.split(",").length == 2
						? from_inches( double.parse(margin.split(",")[1]) )
						: 0;
			// Set margin for main GraphView widget
			widget.margin_top = (int) (margin_y / 2);
			widget.margin_bottom = (int) (margin_y / 2);
			widget.margin_start = (int) (margin_x / 2);
			widget.margin_end = (int) (margin_x / 2);

		}

		*/

		protected override void measure (Gtk.Widget widget,
										Gtk.Orientation orientation,
										int for_size,
										out int minimum,
										out int natural,
										out int minimum_baseline,
										out int natural_baseline) {

			if ( ! widget.get_type().is_a(typeof(GraphView)) ) {
				critical ( "Expected GraphView widget");
				base.measure( widget, orientation, for_size,
					out minimum, out natural, out minimum_baseline, out natural_baseline );
				return;
			}

			try {

				// we use -Tjson0 instead of -Tjson as we only need bb,margin attributes
				// for measuring the main graph widget.
				Json.Object obj = graphviz_exec( this.generate_dot_for_preferred_size( widget ), {
										"dot",
											"-Gdpi=%g".printf(
												(double) widget.get_settings().gtk_xft_dpi / 1024 ),
											"-Tjson0" });
				/*
				// If graphviz contains margin attribute and main
				// widget doesn't have any margin assigned, then
				// update widget's margin to ones produced from
				// graphviz.
				if ( obj.has_member("margin") && (
						widget.margin_top == widget.margin_bottom == widget.margin_start == widget.margin_end == 0
					) )
					this.parse_margin( widget, obj.get_string_member("margin") );
				*/

				string bb = obj.get_string_member ("bb");

				if ( orientation == Gtk.Orientation.HORIZONTAL )
					//  Width computed from graphviz
					minimum = natural = bb != null && bb.split(",").length == 4
						? (int) ( double.parse(bb.split(",")[2])  )
						: 0;
				else
					// Height computed from graphviz
					minimum = natural = bb != null && bb.split(",").length == 4
						? (int) ( double.parse( bb.split(",")[3])  )
						: 0;
				minimum_baseline = natural_baseline= -1;

			} catch ( GLib.Error e ) {
				warning ( "Error while measuring graph : %s. Fallback to default", e.message );
				base.measure( widget, orientation, for_size,
					out minimum, out natural, out minimum_baseline, out natural_baseline );
			}
		}

		protected override void allocate (Gtk.Widget widget, int width, int height, int baseline) {

			if ( ! widget.get_type().is_a(typeof(GraphView)) ) {
				critical ( "Expected GraphView widget");
				base.allocate( widget, width, height, baseline );
				return;
			}

			try {

				// Get maximum size from previous allocated size and current allocation.
				double w = to_inches( double.max( widget.get_width(), (double) width) );
				double h = to_inches( double.max( widget.get_height(), (double) height) );

				// Execute graphviz including size flag
				Json.Object obj = graphviz_exec( this.generate_dot_for_preferred_size( widget ), {
										"dot",
											"-Gdpi=%g".printf(
												(double) widget.get_settings().gtk_xft_dpi / 1024),
											"-Gsize=%g,%g".printf( w, h),
											// use "!" to direct graphviz to use provided size as minimum size.
											// "-Gsize=%g,%g\\!".printf( w, h),
											// use request size directly
											// "-Gsize=%g,%g".printf( to_inches( (double) width ), to_inches( (double) height ) ),
											"-Tjson" });

				// Parse graph renderings, useful to draw
				// graph background, label, ...
				this.renderings = Rendering.xdot_parse( obj );

				// Parse nodes
				if ( obj.has_member("objects") ) {
					var arr = obj.get_array_member ("objects");
					if ( arr != null ) {
						arr.foreach_element( (array, idx, element_node) =>{
							var _obj = element_node.get_object();
							if ( _obj != null && _obj.has_member("id") ) {
								int member_id = int.parse( _obj.get_string_member("id") );
								if ( this.nodes.contains(member_id) ) {
									Node node = this.nodes.get(member_id);
									node.set_renderings( Rendering.xdot_parse(_obj, { "_draw_" }) );
									node.child_widget.allocate_size( node.get_allocation(), baseline );
								}
							}
						});
					}
					obj.remove_member ("objects");
				}

				// Parse edges
				if ( obj.has_member("edges") ) {
					var arr = obj.get_array_member ("edges");
					if ( arr != null ) {
						arr.foreach_element( (array, idx, element_node) =>{
							var _obj = element_node.get_object();
							if ( _obj != null && _obj.has_member("id") ) {
								int member_id = int.parse(  _obj.get_string_member("id") );
								Edge edge = this.edges.nth_data(member_id);
								edge.set_renderings( Rendering.xdot_parse(_obj) );
								foreach ( var r in edge.get_renderings() ) {
									if ( r.contains_text() )
										r.expand_text( widget.get_pango_context() );
								}
							}
						});
					}
					obj.remove_member ("edges");
				}

			} catch ( GLib.Error e ) {
				warning ( "Error while allocating graph : %s. Fallback to default", e.message );
				base.allocate( widget, width, height, baseline );
			}
		}

		private string generate_dot_for_preferred_size( Gtk.Widget parent ) {

			GraphView view = parent as GraphView;

			// Initialise graph
			string dot = "digraph {\n"
							+ "\tpad = \"%g\"\n".printf( view.pad )
							+ "\t" + view.extra + "\n"
							// Force node shape to box instead of default ellipse, as
							// we will use node's layout to render Gtk.Widgets inside
							// them. Additionally set fixed size as we are providing
							// the Gtk.Widgets preferred size (see below).
							+ "\tnode [ shape=\"box\" margin=\"0,0\" fixedsize=true ];\n"
						;

			// Serialize nodes to dot format including underline
			// Gtk.Widgets preferred width and height.
			var keys = this.nodes.get_keys ();
			for ( int _k = 0; _k < keys.length(); _k ++ ) {

				Node member = this.nodes.get( keys.nth_data(_k) );

				Gtk.Requisition child_req;
				member.child_widget.get_preferred_size (out child_req, null);

				dot += "\tn%d [ id=\"%d\" label=\"%s\" width=%g height=%g %s ];\n".printf(
						(int) member.id, (int) member.id, member.get_label(),
						// detect max widget's width
						to_inches(
							(double) int.max ( default_child_width, child_req.width )
							+ ( default_margin * 2 ) ),
						// detect max widget's height
						to_inches(
							(double) int.max ( default_child_height, child_req.height)
							+ ( default_margin * 2 ) ),
						// add user provided instructions
						member.extra
					);
			}

			// Serialize edges to dot format.
			for ( int i = 0; i < this.edges.length(); i ++ ) {
				Edge edge = this.edges.nth_data(i);
				dot += "\tn%d -> n%d [ id=\"%d\" label=\"%s\" %s ];\n".printf(
							(int) edge.start, (int) edge.end, i, edge.get_label(), edge.extra);
			}

			dot += "\n}\n"; // Close graph
			return dot;
		}


		/*
		private uint n_members = 0;
		private HashTable<uint, IGraphMember*> members = new HashTable<uint, IGraphMember*> (direct_hash, direct_equal);
		public Node add_node ( Gtk.Widget child ) {
			Node member = new Node(this, child, n_members );
			IGraphMember* ptr = member;
			members.insert( n_members, ptr );
			n_members ++;
			return member;
		}
		public Edge add_edge (uint start, uint end, string extra = "") {
			Edge e = new Edge.new_from_id( start, end );
			e.extra = extra;
			IGraphMember* ptr = e;
			members.insert( n_members, ptr );
			n_members ++;
			return e;
		}

		 **
		 * Iterate through graph nodes (nodes/edges)
		 *
		 * @param func handle member and return `true` to stop iteration or `false` to continue.
		 * @param kind set member kind to handle only nodes or edges, or `null` to handle everything.

		public void foreach_member( DelegateMember func, GraphMemberKind? kind = null ) {
			for ( int i = 0; i < this.nodes.length(); i ++ ) {
				Node member = this.nodes.nth_data(i);
				if ( member == null )
					continue;
				if ( ( kind == null || kind == member.kind ) && func( member ) )
					break;
			}

		}
		public delegate bool DelegateMember ( Node member );
		*/


	}

}
