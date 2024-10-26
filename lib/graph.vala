
namespace Gtkdot {

	public static int default_child_width = 12;
	public static int default_child_height = 6;

	double to_inches( double val ) {
		return val / 25.4 / 3;
	}

	double from_inches( double val ) {
		return val * 25.4 * 3;
	}


	public errordomain GraphError {
		DOT_ERROR,
		CLI_ERROR
	}


	public static Gsk.Path build_eclipse ( Graphene.Rect r ) {
		var builder = new Gsk.PathBuilder();
		builder.move_to (
						r.origin.x - r.size.width,  r.origin.y );
		builder.cubic_to (
						r.origin.x - r.size.width,  r.origin.y,
						r.origin.x - r.size.width,  r.origin.y + r.size.height,
						r.origin.x,                 r.origin.y + r.size.height );
		builder.cubic_to (
						r.origin.x,                 r.origin.y + r.size.height,
						r.origin.x + r.size.width,  r.origin.y + r.size.height,
						r.origin.x + r.size.width,  r.origin.y );
		builder.cubic_to (
						r.origin.x + r.size.width,  r.origin.y,
						r.origin.x + r.size.width,  r.origin.y - r.size.height,
						r.origin.x,                 r.origin.y - r.size.height );
		builder.cubic_to (
						r.origin.x,                 r.origin.y - r.size.height,
						r.origin.x - r.size.width,  r.origin.y - r.size.height,
						r.origin.x - r.size.width,  r.origin.y );
		builder.close();
		return builder.to_path();
	}

	/**
	 * Build B-Spine curve from list of points.
	 *
	 * @param points list of points to build curve.
	 * @param close If set to `true` then it will close the path otherwise not. Useful for filling curves.
	 * @return The result path.
	 */
	public static Gsk.Path build_bspline ( Graphene.Point[] points, bool close = false ) {
		var builder = new Gsk.PathBuilder();
		for ( int i = 0; i < points.length; i += 3 ) {
			if ( i == 0 )
				builder.move_to ( points[i].x, points[i].y );
			else
				builder.cubic_to (
					points[i-2].x, points[i-2].y,
					points[i-1].x, points[i-1].y,
					points[i].x,   points[i].y );
		}
		if ( close )
			builder.close();
		return builder.to_path();
	}

	/**
	 * Build Polygon / Polyline paths from list of points.
	 *
	 * @param points list of points to poly shape.
	 * @param close If set to `true` then it will close the path otherwise not. Useful for Polygon shapes
	 * @return The result path.
	 */
	public static Gsk.Path build_poly ( Graphene.Point[] points, bool close = false ) {
		var builder = new Gsk.PathBuilder();
		for ( int i = 0; i < points.length; i ++ ) {
			if ( i == 0 )
				builder.move_to ( points[i].x, points[i].y );
			else
				builder.line_to ( points[i].x, points[i].y );
		}
		if ( close )
			builder.close();
		return builder.to_path();
	}

	/**
	 * Parses array of points describing a Graphviz B-Spine and builds Gsk.Path.
	 *
	 * The expected array is in json format as produced Graphviz -Tjson output
	 * for example
	 * {{{
	 * ...
	 * "_draw_": [
	 *  	 ...
	 *   {
	 *     "op": "b",
	 *     "points": [[160.390,142.060],[151.200,128.320],[140.980,113.040],[131.420,98.750]]
	 *   }
	 * ]
	 * ...
	 * "_hdraw_": [
	 *  	 ...
	 *   {
	 *     "op": "P",
	 *     "points": [[134.570,97.160],[126.100,90.800],[128.750,101.050]]
	 *   }
	 * ]
	 * ...
	 * }}}
	 *
	 * @param arr Array of points already parsed.
	 * @return List of points.
	 */
	public static Graphene.Point[] parse_points( Json.Array arr ) {
		Graphene.Point[] ret = {};
		for ( int i = 0; i < arr.get_length(); i ++ ) {
			ret += Graphene.Point().init(
				(float) arr.get_array_element(i).get_double_element(0),
				(float) arr.get_array_element(i).get_double_element(1) );
		}
		return ret;
	}


	/**
	 * Pipes provided dot diagram to graphviz cli and returns json object.
	 *
	 * It expects cmd to contain "-Tjson" flag.
	 */
	public Json.Object graphviz_exec ( string dot, string[] cmd = { "dot", "-Tjson" } ) throws GLib.Error {
		debug( "Parsing dot diagram :\n%s", dot );
		var proc = new GLib.Subprocess.newv(cmd,
							GLib.SubprocessFlags.STDIN_PIPE | GLib.SubprocessFlags.STDOUT_PIPE );
		GLib.Bytes stdout_buf = new GLib.Bytes(null);
		GLib.Bytes stderr_buf = new GLib.Bytes(null);
		proc.communicate(
				new GLib.Bytes(dot.data),
				null,
				out stdout_buf,
				out stderr_buf );
		if ( proc.get_exit_status () != 0 )
			throw new GraphError.CLI_ERROR("Error while executing graphviz cli : %s", string.joinv(" ", cmd) );
		Json.Parser parser = new Json.Parser ();
		debug( "Parsed dot diagram to json representation :\n%s", (string) stdout_buf.get_data () );
		parser.load_from_data ( (string) stdout_buf.get_data () );
		Json.Node node = parser.get_root ();
		return node.get_object ();
	}

	/**
	 * Rendering, a class to convert Graphviz x-dot information to Gtk.
	 *
	 * Graphviz xdot is an extension to dot format providing additional
	 * information on how to render a graph. It provides following
	 * additional ''drawing attributes'' see [[https://graphviz.org/docs/outputs/canon/#xdot|docs]]
	 *
	 * * `_draw_` Renders basic shape
	 * * `_ldraw_` Render text label
	 * * `_hdraw_` Render head arrow
	 * * `_tdraw_` Render tail arrow
	 * * `_hldraw_` Render head arrow label
	 * * `_tldraw_` Render tail arrow label
	 *
	 * Each of those elements contain and array of operations such as
	 * //set color//, //set font//, //set style//, //set path//, and others.
	 * Combining those operations will result in rendering either a shape or text.
	 *
	 * Rendering class parses the operations and prepares all parts ( paths, colors, styles,
	 * pango layouts, ... ) to be able to display the corresponding ''drawing attribute''
	 * to Gtk. Each Rendering class object corresponds to a single ''drawing attribute'',
	 * and displays either a shape or text.
	 *
	 * Use `xdot_parse` static function to parse ''drawing attributes'' and
	 * build list of Rendering class objects. To display the object, use
	 * `render`. Additionally `contains` may be used to detect whether a
	 * point ( such as mouse pointer position ) is within object's bounds.
	 *
	 */
	protected class Rendering {

		/*** the actual ''drawing attribute'' `this` corresponds to */
		public string x_dot;

		/*** Color to use for stroke */
		public Gdk.RGBA pen_color;

		/*** Color to use for fill */
		public Gdk.RGBA fill_color;

		/*** pango layout contains all text related information to draw text labels */
		public Pango.Layout? text_layout;

		// Text related
		private Graphene.Rect text_bounds;
		private Graphene.Point text_pos;
		private bool is_text;

		// Shape related
		private Gsk.FillRule fill_rule;
		private Gsk.Path path;
		private bool fill;
		private Gsk.Stroke stroke;

		public Rendering() {
			this.pen_color = { 0.1f, 0.1f, 0.1f, 1 };
			this.fill_color = { 0.8f, 0.8f, 0.8f, 1 };
			this.fill_rule = Gsk.FillRule.EVEN_ODD;
			this.stroke = new Gsk.Stroke(1);
			this.stroke.set_line_cap( Gsk.LineCap.ROUND );
			this.stroke.set_line_join( Gsk.LineJoin.ROUND );
		}

		public void set_text_context ( Pango.Context ctx ) {
			this.text_layout = new  Pango.Layout(ctx);
			this.text_layout.set_wrap( Pango.WrapMode.WORD );
			this.text_pos = Graphene.Point(). init (0, 0);
			this.is_text = true;
		}

		public void set_text_pos ( float x, float y ) {
			this.text_pos = Graphene.Point(). init ( x, y );
		}

		public void set_path ( Gsk.Path path, bool fill = false ) {
			this.path = path;
			this.fill = fill;
			this.is_text = false;
		}

		public void set_style ( string style ) {
			// set line width
			if ( style.has_prefix("setlinewidth") )
				this.stroke.set_line_width (
					int.max(1, int.parse ( style.replace("setlinewidth(", "").replace(")", "") ) )
				);
			// set dotted style
			else if ( style == "dotted" )
				this.stroke.set_dash({ this.stroke.get_line_width () * 4 });
		}


		/**
		 * Check whether point contained in rendering.
		 *
		 * For Rendering object that holds texts it checks against text bounds.
		 * For Rendering object that holds a shape, and shape is a closed path
		 * checks against the shape. If shape is not a closed path then returns
		 * false.
		 *
		 * @param point Point to check whether contained or not.
		 * @return `true` if point is contained `false` otherwise.
		 */
		public bool contains ( Graphene.Point point ) {
			if ( this.is_text )
				return this.text_bounds.contains_point ( point );
			else if ( this.path.is_closed() )
				return this.path.in_fill( point, fill_rule);
			return false;
		}

		public void render (Gtk.Snapshot snapshot,
							Gdk.RGBA? custom_pen_color = null,
							Gdk.RGBA? custom_fill_color = null ) {
			if ( ! this.is_text ) {
				if ( this.fill )
					snapshot.append_fill ( this.path, this.fill_rule,
										custom_fill_color == null ? this.fill_color : custom_fill_color );
				snapshot.append_stroke ( this.path, this.stroke,
										custom_pen_color == null ? this.pen_color : custom_pen_color );
			} else {
				snapshot.save();
				snapshot.translate(this.text_pos);
				snapshot.append_layout( this.text_layout, custom_pen_color == null ? this.pen_color : custom_pen_color );
				snapshot.restore();
				snapshot.append_color({ 0.8f, 0.8f, 0.1f, 0.5f }, this.text_bounds );

			}
		}

		public static Rendering[] xdot_parse(
								Json.Object obj,
								Pango.Context pctx,
								string [] members = {
												"_draw_",
												"_ldraw_",
												"_hdraw_", "_tdraw_", "_hldraw_", "_tldraw_" // edge drawing
												}) {
			Rendering[] ret = {};

			foreach ( string member in members ) {

				if ( obj.has_member(member) ) {
					var arr = obj.get_array_member(member);
					assert_nonnull ( arr );

					Rendering? shape = null;

					arr.foreach_element( (a, i, node) =>{

						var graphviz_op = node.get_object();
						assert_nonnull ( graphviz_op );

						if ( shape == null ) {
							shape = new Rendering();
							shape.set_text_context(pctx);
							shape.x_dot = member;
						}

						// Process operation
						string op = graphviz_op.get_string_member("op");

						switch ( op ) {

							case "C": // Set fill color
								// gradient colors are not yet supported
								if ( graphviz_op.get_string_member("grad") == "none" )
									shape.fill_color.parse( graphviz_op.get_string_member("color") );
								break;
							case "c": // Set pen color
								// gradient colors are not yet supported
								if ( graphviz_op.get_string_member("grad") == "none" )
									shape.pen_color.parse( graphviz_op.get_string_member("color") );
								break;
							case "S": // Set style attribute
								shape.set_style( graphviz_op.get_string_member("style") );
								break;

							case "E": // Filled ellipse
							case "e": // Unfilled ellipse
								shape.set_path(
									build_eclipse(
										Graphene.Rect().init(
											(float) arr.get_double_element (0),
											(float) arr.get_double_element (1),
											(float) arr.get_double_element (2),
											(float) arr.get_double_element (3)
										)
									),
									// fill eclipse if operation is capital E
									op == "E"
								);
								ret += shape;
								shape = null;
								break;

							case "P": // Filled polygon
							case "p": // Unfilled polygon
							case "L": // Polyline
								shape.set_path(
									build_poly(
										parse_points( graphviz_op.get_array_member("points") ),
										// Close shape only for polygon types
										( op == "P" || op == "p" )
									),
									// fill polygon if operation is capital P
									op == "P"
								);
								ret += shape;
								shape = null;
								break;

							case "B": // B-spline
							case "b": // Filled B-spline
								shape.set_path(
									build_bspline(
										parse_points( graphviz_op.get_array_member("points") ),
										// close b-spine curves only when they expect to be
										// filled
										// op == "B"
										false
									),
									// fill b-spine if operation is capital B
									op == "B"
								);
								ret += shape;
								shape = null;
								break;

							case "t": // Set font characteristics
							case "F": // Set font
								if ( shape.text_layout == null )
									 shape.set_text_context(pctx);
								Pango.FontDescription font = Pango.FontDescription.from_string (
										graphviz_op.get_string_member("face")
									);
								font.set_absolute_size(
									graphviz_op.get_double_member("size") * Pango.SCALE );
								// set font face
								shape.text_layout.set_font_description ( font );
								break;

							case "T": // Set text
								switch ( graphviz_op.get_string_member("align") ) {
									case "c":
										shape.text_layout.set_alignment( Pango.Alignment.CENTER );
										break;
									// ....
									default:
										shape.text_layout.set_alignment( Pango.Alignment.LEFT );
										break;
								}
								shape.text_layout.set_width( (int) graphviz_op.get_double_member("width") );
								shape.text_layout.set_text( graphviz_op.get_string_member("text"), -1 );

								// Set text position
								var pos = graphviz_op.get_array_member("pt");

								int tw=0;
								int th=0;
								// shape.text_layout.get_size(out tw, out th);
								// shape.set_text_pos(
								//	(float) pos.get_double_element (0),
								//	(float) pos.get_double_element (1) - ( (float) th  / Pango.SCALE / 2 ) );
								shape.text_layout.get_pixel_size(out tw, out th);
								shape.set_text_pos(
									(float) pos.get_double_element (0),
									(float) pos.get_double_element (1) /* - ( (float) th / 2 ) */ );
								shape.text_bounds = Graphene.Rect().init(
										shape.text_pos.x - ( (float) tw / 2),
										shape.text_pos.y,
										(float) tw,
										(float) th );
								ret += shape;
								shape = null;
								break;

							case "I": // Externally-specified image drawn in the box
							default:
								break;
						}
					});
				}
			}
			return ret;
		}

	}



	public interface GraphMember : GLib.Object {

		public virtual void render(Gtk.Snapshot snapshot) {
			foreach ( var rendering in this.get_renderings() )
				rendering.render(snapshot);
		}

		public virtual bool contains (Graphene.Point point) {
			foreach ( var rendering in this.get_renderings() ) {
				if ( rendering.contains(point) )
					return true;
			}
			return false;
		}

		public virtual void validate_json(Json.Object obj) throws GraphError  {
			if ( ! obj.has_member("id") || this.get_dot_id () != obj.get_string_member("id")  )
				throw new GraphError.DOT_ERROR("Could not parse id for: %s\n", this.get_dot_id () );
		}

		public virtual void parse_json( Json.Object obj, Pango.Context pctx ) {
			set_renderings( Rendering.xdot_parse( obj, pctx ) );
		}

		protected abstract void set_renderings( Rendering[] renderings );
		protected abstract Rendering[] get_renderings();
		public abstract string to_dot ();
		public abstract string get_dot_id ();

	}












}


/*

digraph {
	graph [ margin="0.4,0.4" ];
	node [ shape="box" margin="0,0"  ];
	n0 [ id="n0" label="0.GtkLabel" width=3.93701 height=1.9685 ];
	n1 [ id="n1" label="1.GtkButton" width=6.06299 height=1.9685 ];
	n2 [ id="n2" label="2.GtkLabel" width=3.93701 height=1.9685 ];
	n3 [ id="n3" label="3.GtkImage" width=3.93701 height=1.9685 ];
	n4 [ id="n4" label="4.GtkButton" width=3.93701 height=1.9685 ];
	n5 [ id="n5" label="5.GtkButton" width=3.93701 height=1.9685 ];
	n2 -> n1 [id="e0" label="e0"  ];
	n3 -> n1 [id="e1" label="e1"  ];
	n1 -> n0 [id="e2" label="e2"  ];
	n2 -> n0 [id="e3" label="e3"  ];
	n3 -> n2 [id="e4" label="e4" penwidth=2 arrowsize=3.5 style=dotted ];
	n4 -> n3 [id="e5" label="e5"  ];
	n5 -> n3 [id="e6" label="e6"  ];

n0
	pos: "402.73,70.866"
	height: "1.9685"
	width: "3.937"
	points: [[544.460,141.730],[261.000,141.730],[261.000,0.000],[544.460,0.000]]

n3
	pos: "291.73,655.81"
	width: "3.937"
	height: "1.9685"
	points: [[433.460,726.680],[150.000,726.680],[150.000,584.950],[433.460,584.950]]




		 * Executes graphviz cli and parse basic information for graph.
		 *
		 * This is used mainly to quickly gather graph information ( e.g bounding box )
		 * without the need to parse nodes or edges.
		 *
		 * Parsing use graphviz json output (with xdot information) thus
		 * expects cmd to contain "-Tjson" flag.

		public bool compute_layout () {
			Json.Object? jdot = null;
			try {
				var proc = new GLib.Subprocess.newv({
									"dot",
										"-Gdpi=%g".printf( this.get_dpi() ),
										"-Tjson" },
									GLib.SubprocessFlags.STDIN_PIPE | GLib.SubprocessFlags.STDOUT_PIPE );

				GLib.Bytes stdout_buf = new GLib.Bytes(null);
				GLib.Bytes stderr_buf = new GLib.Bytes(null);
				string data = this.dot_serialize();
				print("\n\n\n-----------------------------------------------------------------\n%s\n\n", data);
				proc.communicate(
					new GLib.Bytes(data.data ),
					null,
					out stdout_buf,
					out stderr_buf );

				if ( proc.get_exit_status () == 0 ) {
					Json.Parser parser = new Json.Parser ();
					print( (string) stdout_buf.get_data () );
					parser.load_from_data ( (string) stdout_buf.get_data () );
					Json.Node node = parser.get_root ();
					jdot = node.get_object ();
				} else {
					warning("Error while parsing dot diagram (stdout, stderr): %s\n%s",
						(string) stdout_buf.get_data (),
						(string) stderr_buf.get_data ()
					);
				}
			} catch ( GLib.Error e ) {
				warning("Error while parsing dot diagram : %s", e.message);
			}

			if ( jdot == null) return false;

			this.bb = jdot.get_string_member ("bb");
			this.margin = jdot.get_string_member ("margin");

			// Set margin for main GraphView widget
			view.margin_top = (int) (dot_margin_y / 2);
			view.margin_bottom = (int) (dot_margin_y / 2);
			view.margin_start = (int) (dot_margin_x / 2);
			view.margin_end = (int) (dot_margin_x / 2);




			return true;
		}
		 */
