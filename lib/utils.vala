namespace Gtkdot {

	public enum GraphMemberKind {
		  NODE
		, EDGE
		// , SUBGRAPH Not implemented
		;
	}

	/*** At present, most device-independent units are either inches or points, which we take as 72 points per inch. */
	public static double points_to_inches(double p) { return p / 72; }
	public static double inches_to_points(double p) { return p * 72; }

	/*** Parse graphviz bounding box and return width */
	public static double get_bb_w(string bb ) {
		return ( bb != null && bb.split(",").length == 4 )
			? double.parse( bb.split(",")[2] )
			: 0;
	}

	/*** Parse graphviz bounding box and return height */
	public static double get_bb_h(string bb) {
		return ( bb != null && bb.split(",").length == 4 )
			? double.parse( bb.split(",")[3] )
			: 0;
	}

	public static string get_widget_id (Gtk.Widget widget) {
		if ( widget.get_id() == null ) {
			Gtk.Widget* _ptr = widget;
			return  "%p".printf(_ptr);
		}
		return widget.get_id();
	}

	public delegate bool TraverseNode( Gvc.Graph graph, Gtk.Widget node_widget, Gvc.Node node);


	/**
	 * Process internal graphviz diagram and return result.
	 *
	 * @param output_format Graphviz format to use as output, dot|xdot|png|json|...
	 * @return raw data of the rendered diagram.
	 */
	public static uint8[] render_diagram( Gvc.Graph _graph, string layout_engine = "dot", string output_format = "dot" ) {
		uint8[] ret = {};
		Gvc.Context _ctx = new Gvc.Context();
		_ctx.layout(_graph, layout_engine );
		_ctx.render_data(_graph, output_format, out ret);
		_ctx.free_layout(_graph);
		return ret;
	}

	/*** Returns internal graphviz diagram as Gdk.Texture. */
	public static Gdk.Texture render_texture( Gvc.Graph _graph, string layout_engine = "dot",  string format = "svg" ) throws GLib.Error {
		return Gdk.Texture.from_bytes (
					new GLib.Bytes (
						render_diagram (_graph, layout_engine, format) ) );
	}

	public static Gdk.Pixbuf render_pixbuf( Gvc.Graph _graph, string layout_engine = "dot", string format = "png" ) throws GLib.Error {
		return new Gdk.Pixbuf.from_stream (
					new MemoryInputStream.from_bytes (
						new GLib.Bytes (
							render_diagram (_graph, layout_engine, format) )
					)
				);
	}

	public void parse_xdot (string? xdot, out Gsk.Path path) {
		path = null;
		if ( xdot == null )
			return;

		string[] parts = xdot.split(" ");
		for ( int i = 0; i < parts.length; i++ ) {
			switch ( parts[i] ) {
						case "b": // B-Spine
						case "B": // Filled B-Spine
							i++;
							path = build_bspline(
									parse_xdot_points(parts, ref i), ( parts[i-1] == "B" ) );
							break;
						case "L": // Polyline
						case "P": // Filled Polygon
						case "p": // Polygon
							i++;
							path = build_poly(
										parse_xdot_points(parts, ref i),
										// Close poly when polygon
										( parts[i-1] == "P" || parts[i-1] == "p" )
									);
							break;
						case "E":
						case "e":
						case "t":
						case "T":
						case "F":
						case "c":
						case "C":
						default:
							break;
			}

		}

	}

	public static Graphene.Point[] parse_xdot_points ( string[] parts, ref int i ) {
		Graphene.Point[] points = {};
		// number of points
		int n_points = int.parse( parts[i] );
		i++;
		while ( n_points != 0 ) {
			Graphene.Point _p = Graphene.Point().init(
				(float) double.parse( parts[ i ] ),
				(float) double.parse( parts[ i + 1] )
			);
			points += _p;
			n_points -= 1;
			i += 2;
		}
		return points;
	}

	/**
	 * Build ellipse from rectangle
	 *
	 * @param r rectangle to build ellipse from
	 * @return The result path.
	 */
	public static Gsk.Path build_ellipse ( Graphene.Rect r ) {
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
	 * Build Polygon / Polyline path from list of points.
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
	 *
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
	 *
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
		if ( proc.get_exit_status () != 0 ) {
			warning( "Invalid dot diagram :\n%s", dot );
			throw new GraphError.CLI_ERROR("Error while executing graphviz cli : %s", string.joinv(" ", cmd) );
		}
		Json.Parser parser = new Json.Parser ();
		debug( "Parsed dot diagram to json representation :\n%s", (string) stdout_buf.get_data () );
		parser.load_from_data ( (string) stdout_buf.get_data () );
		Json.Node node = parser.get_root ();
		return node.get_object ();
	}
	 */

}

