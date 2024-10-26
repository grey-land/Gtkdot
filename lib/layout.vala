namespace Gtkdot {

	public enum GraphMemberKind {
		NODE,
		EDGE;
	}

	public class GraphLayoutChild : Gtk.LayoutChild, GraphMember {

		// public GraphLayoutKind kind { get; construct; };

		private int idx;
		private GLib.List<int> edge_headed;
		private GLib.List<int> edge_tailed;
		private Rendering[] renderings;
		private string _margin;
		private string _width;
		private string _height;
		private string _pos;
		private double dot_margin_x  { get { return double.parse( _margin.split(",")[0] ) / 0.0104; } }
		private double dot_margin_y  { get { return double.parse( _margin.split(",")[1] ) / 0.0104; } }
		private double dot_width     { get { return from_inches( double.parse(_width) )  - dot_margin_x ; } }
		private double dot_height    { get { return from_inches( double.parse(_height) )  - dot_margin_y  ;  } }
		private double dot_x         { get { return double.parse( _pos.split(",")[0] ) - ( dot_width / 2 ); } }
		private double dot_y         { get { return double.parse( _pos.split(",")[1] ) - ( dot_height / 2 ); } }


		public GraphLayoutChild (Gtk.LayoutManager manager, Gtk.Widget child, int idx) {
			GLib.Object(
				layout_manager: manager,
				child_widget: child
			);
			this.renderings = {};
			this.idx = idx;
		}

		public void add_edge_tailed (int edge_id) { this.edge_tailed.append( edge_id ); }

		public void add_edge_headed (int edge_id) { this.edge_headed.append( edge_id ); }

		public void allocate (Gtk.Widget parent, int width, int height, int baseline) {
			this.child_widget.margin_top    = (int) this.dot_margin_y / 2;
			this.child_widget.margin_bottom = (int) this.dot_margin_y / 2;
			this.child_widget.margin_start  = (int) this.dot_margin_x / 2;
			this.child_widget.margin_end    = (int) this.dot_margin_x / 2;
			this.child_widget.allocate_size ({
						(int) dot_x, (int) dot_y,
						(int) dot_width, (int) dot_height }, baseline );
		}

		public Gsk.RoundedRect get_rounded_rect(float? radius = 0) {
			return Gsk.RoundedRect().init_from_rect (
						Graphene.Rect().init(
							(float) dot_x, (float) dot_y, (float) dot_width, (float) dot_height ), radius);
		}

		protected Rendering[] get_renderings() {
			return renderings;
		}

		protected void set_renderings( Rendering[] renderings ) {
			this.renderings = renderings;
		}

		public override void parse_json(Json.Object obj, Pango.Context pctx) {
			this.validate_json(obj);
			if ( obj.has_member( "margin" ) ) this._margin = obj.get_string_member("margin");
			if ( obj.has_member( "width"  ) ) this._width  = obj.get_string_member("width");
			if ( obj.has_member( "height" ) ) this._height = obj.get_string_member("height");
			if ( obj.has_member( "pos"    ) ) this._pos    = obj.get_string_member("pos");
			this.renderings = Rendering.xdot_parse( obj, pctx );
		}

		public override void render(Gtk.Snapshot snapshot) {

			if ( ! child_widget.should_layout () )
				return;

			// Gtk Border
			Gdk.RGBA color = Gdk.RGBA();
			color.parse("#e80e0e");
			snapshot.append_border(
					this.get_rounded_rect(),
					// top, right, bottom and left
					{ 1, 1, 1, 1 }, { color, color, color, color } );

			foreach ( var r in this.renderings ) {
				if ( r.x_dot == "_draw_" )
					r.render(snapshot);
			}
		}

		public string get_dot_id () {
			return "n%d".printf(this.idx);
		}

		public string to_dot () {
			Gtk.Requisition child_req;
			this.child_widget.get_preferred_size (out child_req, null);
			// generate dot description for widget
			return "%s [ id=\"%s\" width=%g height=%g margin=\"%g,%g\" ];".printf(
					this.get_dot_id(),
					this.get_dot_id(),
					// detect max widget's width
					to_inches( (double) int.max ( default_child_width, child_req.width ) ),
					// detect max widget's height
					to_inches( (double) int.max ( default_child_height, child_req.height ) ),
					// detect max margins of widget's x-axis
					to_inches( double.max ( 1,
								(double) (
									this.child_widget.margin_start +
									this.child_widget.margin_end ) / 2 ) ),
					// detect max margins of widget's y-axis
					to_inches( double.max ( 1,
								(double) (
									this.child_widget.margin_top +
									this.child_widget.margin_bottom ) / 2 ) )
				);
		}

	}



	public class GraphLayoutManager : Gtk.LayoutManager {



		private string margin;
		private string bb;
		private GLib.List<Edge> edges;
		private Rendering[] shapes;

		/*** Margin for X axis computed from graphviz */
		protected double dot_margin_x  {
			get { return margin != null && margin.split(",").length == 2 ?
					from_inches( double.parse(margin.split(",")[0]) ) : 0; } }

		/*** Margin for Y axis computed from graphviz */
		protected double dot_margin_y  {
			get { return margin != null && margin.split(",").length == 2 ?
					from_inches( double.parse(margin.split(",")[1]) ) : 0; } }

		/*** Width computed from graphviz */
		protected double dot_width {
			get { return bb != null && bb.split(",").length == 4 ? double.parse( bb.split(",")[2] ) /*- dot_margin_x*/ : 0; } }

		/*** Height computed from graphviz */
		protected double dot_height {
			get { return bb != null && bb.split(",").length == 4 ? double.parse( bb.split(",")[3] ) /*- dot_margin_y*/ : 0; } }

		/*** Main GraphView Widget */
		public GraphView view { get { return get_widget () as GraphView; } }

		public GraphLayoutManager () {
			this.edges = new GLib.List<Edge> ();
		}

		/**
		 * Add new edge.
		 *
		 * Creates new edge, add it to list of edges,
		 * and add back-references to connected nodes.
		 */
		public void add_edge (int head, int tail, string extra = "" ) {

			int edge_id = (int) edges.length();
			var edge = new Edge( edge_id, head, tail, extra );
			edges.append(edge);

			GraphLayoutChild lc;
			lc = this.get_element( head );
			lc.add_edge_headed(edge_id);

			lc = this.get_element( tail );
			lc.add_edge_tailed(edge_id);
			print("Added Edge: %s\n", edge.to_dot () );
		}

		/**
		 * Retrieve layout child
		 *
		 * @param pos index of layout child to retrieve
		 */
		public GraphLayoutChild? get_element(uint pos) {
			Gtk.Widget? child = null;
			uint i = 0;
			for ( child = view.get_first_child (); child != null; child = child.get_next_sibling() ) {
				// if (!child.should_layout ()) continue;
				if ( i == pos )
					return this.get_layout_child( child ) as GraphLayoutChild;
				i ++;
			}
			return null;
		}

		/*** Get number of layout children */
		public int n_elements() {
			int i = 0;
			Gtk.Widget? child = null;
			for ( child = view.get_first_child (); child != null; child = child.get_next_sibling() ) {
				// if (!child.should_layout ()) continue;
				i ++;
			}
			return i;
		}

		/*** Get index for given widget */
		public int index_element(Gtk.Widget widget) {
			int i = 0;
			Gtk.Widget? child = null;
			for ( child = view.get_first_child (); child != null; child = child.get_next_sibling() ) {
				// if ( !child.should_layout () ) continue;
				if ( child == widget )
					break;
				i ++;
			}
			return i;
		}

		/**
		 * Function to detect edge being clicked
		 */
		public Edge? edge_contains (Graphene.Point point) {

			// We loop from last to first edge as last is rendered on top
			for ( int i = (int) this.edges.length() - 1; i >= 0; i -- ) {
				var edge = this.edges.nth_data(i);
				if ( edge == null )
					continue;
				if ( edge.contains( point ) )
					return edge;
			}
			return null;
		}

		public void render(Gtk.Snapshot snapshot) {

			// graphviz
			foreach ( var shape in this.shapes )
				shape.render(snapshot);

			GraphLayoutChild layout_child;

			for ( int i = 0; i < this.n_elements(); i ++ ) {
				layout_child = this.get_element(i);
				if ( layout_child.child_widget.should_layout () )
					layout_child.render(snapshot);
			}

			this.edges.@foreach( ( edge )=>{
				if ( edge_is_visible( edge ) )
					edge.render( snapshot );
			});


		}

		public override Gtk.LayoutChild create_layout_child (Gtk.Widget container, Gtk.Widget child) {
			return new GraphLayoutChild(this, child, index_element(child) );
		}

		protected override Gtk.SizeRequestMode get_request_mode (Gtk.Widget widget) {
			return Gtk.SizeRequestMode.CONSTANT_SIZE;
		}

		protected override void measure (Gtk.Widget widget,
										Gtk.Orientation orientation,
										int for_size,
										out int minimum,
										out int natural,
										out int minimum_baseline,
										out int natural_baseline) {
			try {

				// we use -Tjson0 instead of -Tjson as we only need bb,margin attributes
				// for measuring the main graph widget.
				Json.Object obj = graphviz_exec( this.generate_dot_for_preferred_size(), {
										"dot",
											"-Gdpi=%g".printf(
												(double) view.get_settings().gtk_xft_dpi / 1024 ),
											"-Tjson0" });

				this.bb = obj.get_string_member ("bb");
				this.margin = obj.get_string_member ("margin");

				// Set margin for main GraphView widget
				view.margin_top = (int) (dot_margin_y / 2);
				view.margin_bottom = (int) (dot_margin_y / 2);
				view.margin_start = (int) (dot_margin_x / 2);
				view.margin_end = (int) (dot_margin_x / 2);

				if ( orientation == Gtk.Orientation.HORIZONTAL )
					minimum = natural = (int) ( dot_width /* + dot_margin_x */ );
				else
					minimum = natural = (int) ( dot_height /* + dot_margin_y */ );
				minimum_baseline = natural_baseline= -1;
			} catch ( GLib.Error e ) {
				warning ( "Error while measuring graph : %s. Fallback to default", e.message );
				base.measure( widget, orientation, for_size,
					out minimum, out natural, out minimum_baseline, out natural_baseline );
			}
		}

		protected override void allocate (Gtk.Widget widget, int width, int height, int baseline) {
			try {

				// We execute graphviz setting the size allocated to the widget
				Json.Object obj = graphviz_exec( this.generate_dot_for_preferred_size(), {
										"dot",
											"-Gsize=%g,%g".printf( to_inches( (double) width ), to_inches( (double) height ) ),
											"-Gdpi=%g".printf(
												(double) view.get_settings().gtk_xft_dpi / 1024),
											"-Tjson" });
				// update properties
				this.bb = obj.get_string_member ("bb");
				this.margin = obj.get_string_member ("margin");

				// Parse all nodes and edges. Once parsed layout children will
				// contain allocation information.
				this.parse_json(obj);

				// Iterate through nodes and allocate graphviz's comptuted positions.
				GraphLayoutChild layout_child;
				for ( int i = 0; i < this.n_elements(); i ++ ) {
					layout_child = this.get_element(i);
					layout_child.allocate(widget, width, height, baseline);
				}

			} catch ( GLib.Error e ) {
				warning ( "Error while allocating graph : %s. Fallback to default", e.message );
				base.allocate( widget, width, height, baseline );
			}
		}


		/*** check whether edge is visible */
		private bool edge_is_visible( Edge edge ) {
			return this.get_element( edge.get_head() ).child_widget.should_layout () &&
					this.get_element( edge.get_tail() ).child_widget.should_layout ();
		}

		/**
		 * Parses graphviz xdot result and generate render context for diagram.
		 *
		 * The provided json object is expected to be the result of a cmd `graphviz_exec`
		 * that been run explicitly with `-Tjson` flag. This is because the `-Tjson` flag
		 * contains extended information for the graph ( _draw_, _ldraw_, ... keys ) that
		 * is being used for render the edges, arrows, borders, ... .
		 *
		 */
		private void parse_json ( Json.Object jdot ) {

			// Parse nodes
			if ( jdot.has_member("objects") ) {
				var objects = jdot.get_array_member ("objects");
				assert( objects != null );
				GraphLayoutChild? layout_child = null;
				objects.foreach_element( (array, idx, element_node) =>{
					layout_child = this.get_element(idx);

					try {
						layout_child.validate_json( element_node.get_object() );
					} catch ( GLib.Error e ) {
						critical( e.message );
					}

					layout_child.parse_json(element_node.get_object(), view.get_pango_context() );

				});
				jdot.remove_member ("objects");
			}

			// Parse edges
			if ( jdot.has_member("edges") ) {
				// this.edges = new GLib.List<Edge> ();
				var _edges = jdot.get_array_member ("edges");
				_edges.foreach_element( (array, idx, element_node) =>{
					Edge edge = this.edges.nth_data( idx );
					try {
						edge.validate_json( element_node.get_object() );
					} catch ( GLib.Error e ) {
						critical( e.message );
					}
					edge.parse_json(element_node.get_object(), view.get_pango_context() );
				});
				jdot.remove_member ("edges");
			}

			// Parse graph
			this.shapes = Rendering.xdot_parse( jdot, view.get_pango_context(), {"_draw_"});
		}

		private string generate_dot_for_preferred_size() {

			// Initialise graph
			string dot = "digraph {\n" +
							// "\trankdir=\"LR\"\n" +
							"\tmargin=\"0.4,0.4\"\n" +
							"\tbgcolor=\"white:lightblue\"\n" +
							// "\tgraph [ margin=\"0.4,0.4\" bgcolor=\"white:lightblue\" directed=true ];\n" +
							"\tnode [ shape=\"box\" margin=\"0,0\" fixedsize=true ];\n";

			// Add nodes
			GraphLayoutChild layout_child;
			for ( int i = 0; i < this.n_elements(); i ++ ) {
				layout_child = this.get_element(i);
				dot += "\t%s\n".printf( layout_child.to_dot() );
				/*
				Gtk.Requisition child_req;
				layout_child.child_widget.get_preferred_size (out child_req, null);
				// generate dot description for widget
				dot += "\tn%d [ id=\"n%d\" width=%g height=%g margin=\"%g,%g\" ];\n".printf(
					i, i,
					// detect max widget's width
					to_inches( (double) int.max ( default_child_width, child_req.width ) ),
					// detect max widget's height
					to_inches( (double) int.max ( default_child_height, child_req.height ) ),
					// detect max margins of widget's x-axis
					to_inches( double.max ( 1,
								(double) (
									layout_child.child_widget.margin_start +
									layout_child.child_widget.margin_end ) / 2 ) ),
					// detect max margins of widget's y-axis
					to_inches( double.max ( 1,
								(double) (
									layout_child.child_widget.margin_top +
									layout_child.child_widget.margin_bottom ) / 2 ) )
				);
				*/
			}

			// Add edges
			foreach ( var edge in this.edges )
				dot += "\t%s\n".printf( edge.to_dot() );


			dot += "\n}\n";
			return dot;
		}

	}

}
