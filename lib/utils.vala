namespace Gtkdot {

	public static int default_child_width = 40;
	public static int default_child_height = 40;
	public static int default_margin = 2;

	public errordomain GraphError {
		DOT_ERROR,
		CLI_ERROR
	}

	double to_inches( double val ) {
		return val / 25.4 / 3;
	}

	double from_inches( double val ) {
		return val * 25.4 * 3;
	}

	public delegate bool DelegateMember ( GvcGraphMember member );

	public enum GvcGraphMemberKind {
		  NODE
		, EDGE
		// , SUBGRAPH Not implemented
		;
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

