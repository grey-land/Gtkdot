
namespace Gtkdot {

	/**
	 * Rendering class converts Graphviz xdot information to Gtk.
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

		public Gsk.Path path;
		public Graphene.Point offset;

		// Text related
		public string text_face = "Sans";
		public Pango.Alignment text_align;
		public double text_size = 14;
		public double text_width = 0;
		public string text_data = "";

		public bool contains_text() {
			return x_dot == "_ldraw_"   // text label
				|| x_dot == "_hldraw_"  // head arrow label
				|| x_dot == "_tldraw_"; // tail arrow label
		}

		// Shape related
		private Gsk.FillRule fill_rule;
		// private Gsk.Path path;
		private bool fill;
		private Gsk.Stroke stroke;

		public Rendering() {
			this.pen_color = { 0.1f, 0.1f, 0.1f, 1 };
			this.fill_color = { 0.8f, 0.8f, 0.8f, 1 };
			this.fill_rule = Gsk.FillRule.EVEN_ODD;
			this.stroke = new Gsk.Stroke(1);
			this.stroke.set_line_cap( Gsk.LineCap.ROUND );
			this.stroke.set_line_join( Gsk.LineJoin.ROUND );
			this.offset = Graphene.Point(). init (0, 0);
		}

		public void set_path ( Gsk.Path path, bool fill = false ) {
			this.path = path;
			this.fill = fill;
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
			if ( this.path.is_closed() )
				return this.path.in_fill( point, fill_rule);
			return false;
		}

		/*** Pango layout contains all text related information to draw text labels */
		public Pango.Layout get_pango_layout ( Pango.Context ctx ) {
			Pango.Layout ret = new Pango.Layout(ctx);
			ret.set_wrap( Pango.WrapMode.WORD );
			Pango.FontDescription font = Pango.FontDescription.from_string(this.text_face);
			font.set_absolute_size( this.text_size * Pango.SCALE );
			ret.set_font_description ( font );
			ret.set_alignment(this.text_align);
			ret.set_width( (int) this.text_width );
			ret.set_text( this.text_data, -1 );
			ret.set_justify(true);
			ret.set_single_paragraph_mode(true);
			return ret;
		}

		/*** Calculate text bounding path (pos + size) */
		public void expand_text ( Pango.Context ctx, bool fix_height = false ) {
			// Set text position
			Pango.Layout pl = this.get_pango_layout(ctx);
			int tw=0;
			int th=0;
			// pl.get_size(out tw, out th);
			pl.get_pixel_size(out tw, out th);
			if ( fix_height )
				this.offset.y -= (float) th / 2;
			Gsk.PathBuilder pb = new Gsk.PathBuilder();
			pb.add_rect(
				Graphene.Rect().init(
						this.offset.x,
						this.offset.y,
						(float) tw,
						(float) th ) );
			pb.close();
			this.path = pb.to_path();
		}

		public void render (Gtk.Snapshot snapshot, Pango.Context ctx,
							Gdk.RGBA? custom_pen_color = null,
							Gdk.RGBA? custom_fill_color = null ) {
			snapshot.save();
			snapshot.translate(this.offset);

			if ( this.contains_text() ) {

				snapshot.append_layout(
						this.get_pango_layout(ctx),
						custom_pen_color == null ? this.pen_color : custom_pen_color );
			} else {

				if ( this.fill )
					snapshot.append_fill ( this.path, this.fill_rule,
								custom_fill_color == null ? this.fill_color : custom_fill_color );

				snapshot.append_stroke ( this.path, this.stroke,
								custom_pen_color == null ? this.pen_color : custom_pen_color);
			}
			snapshot.restore();
		}

		public static Rendering[] xdot_parse(
								Json.Object obj,
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
								var _points = graphviz_op.get_array_member("rect");
								shape.set_path(
									build_ellipse(
										Graphene.Rect().init(
											(float) _points.get_double_element (0),
											(float) _points.get_double_element (1),
											(float) _points.get_double_element (2),
											(float) _points.get_double_element (3)
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
								break;
							case "F": // Set font
								shape.text_face = graphviz_op.get_string_member("face");
								shape.text_size = graphviz_op.get_double_member("size");
								break;
							case "T": // Set text
								var pos = graphviz_op.get_array_member("pt");
								shape.offset = Graphene.Point(). init (
									(float) pos.get_double_element (0),
									(float) pos.get_double_element (1) );
								switch (  graphviz_op.get_string_member("align") ) {
									case "c":
										shape.text_align = Pango.Alignment.CENTER;
										break;
									// ....
									default:
										shape.text_align = Pango.Alignment.LEFT;
										break;
								}
								shape.text_width = (int) graphviz_op.get_double_member("width");
								shape.text_data = graphviz_op.get_string_member("text");
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

	public enum GraphMemberKind {
		NODE,
		EDGE;

		public string to_string() {
			switch (this) {
				case NODE:
					return "Graph Node";
				case EDGE:
					return "Graph Edge";
				default:
					assert_not_reached();
			}
		}

	}

	public interface IGraphMember : GLib.Object {

		public virtual void render(Gtk.Snapshot snapshot, Pango.Context ctx) {
			foreach ( var rendering in this.get_renderings() )
				rendering.render(snapshot, ctx);
		}

		public virtual bool contains (Graphene.Point point) {
			foreach ( var rendering in this.get_renderings() ) {
				if ( rendering.contains(point) )
					return true;
			}
			return false;
		}

		public abstract GraphMemberKind get_kind ();

		public virtual string get_label() {
			return "";
		}

		public abstract Rendering[] get_renderings();
		public abstract void set_renderings( Rendering[] val);

		public abstract Gtk.Allocation get_allocation();

		public virtual Graphene.Rect get_allocation_rect() {
			Gtk.Allocation alloc = this.get_allocation();
			return Graphene.Rect().init(
						(float) alloc.x,
						(float) alloc.y,
						(float) alloc.width,
						(float) alloc.height
					);
		}

		public abstract void set_selected(bool val);
		public abstract bool is_selected();

	}


}
