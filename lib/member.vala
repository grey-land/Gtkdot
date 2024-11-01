namespace Gtkdot {

	public interface GvcGraphMember : GvcMember {

		public abstract Gtk.Allocation get_allocation(bool? update = false );
		public abstract GvcGraphMemberKind get_kind();
		public abstract void snapshot(Gtk.Snapshot snapshot,
							Pango.Context p_ctx,
							Gsk.Stroke stroke,
							Gsk.Shadow shadow,
							Gdk.RGBA color );

		public abstract GLib.Object get_object();
		public abstract void set_selected(bool val);
		public abstract bool is_selected();
		public abstract bool is_visible();
		public abstract string name();

		public virtual Graphene.Rect get_allocation_rect() {
			Gtk.Allocation alloc = this.get_allocation();
			return Graphene.Rect().init(
						(float) alloc.x,
						(float) alloc.y,
						(float) alloc.width,
						(float) alloc.height
					);
		}

		public virtual bool contains_selection (Graphene.Rect selection) {
			Graphene.Rect r = this.get_allocation_rect();
			return r.contains_point(selection.origin) || selection.intersection(r, null);
		}

	}


	public class GvcGraphNode : Gtk.LayoutChild, GvcMember, GvcGraphMember {

		public Gvc.Node node { get; construct; }
		public bool selected { get; set; }
		public GraphLayout layout {
			get { return layout_manager as GraphLayout; }
		}

		private Gtk.Allocation? _alloc = null;

		public GvcGraphNode (Gtk.LayoutManager manager, Gtk.Widget child, Gvc.Node node) {

			GLib.Object(
				layout_manager: manager,
				child_widget: child,
				node: node
			);

			// Assign default node values

			// We set node shape to box instead of ellipse (default)
			// so graphviz layouts edges correctly, respecting Gtk.Widget bounds.
			// Only rectangular Gtk.Widgets are supported.
			this.node.safe_set("shape", "box", "");

			// No need to set node's size to fixed, as widget's size is not yet allocated
			// and will arise from graph.
			// this.node.safe_set("fixedsize", "true", "");

			/* assign margin
			this.node.safe_set("margin", "%g,%g".printf(
					to_inches( (double) ( child.margin_start + child.margin_end ) ),
					to_inches( (double) ( child.margin_top + child.margin_bottom ) )
				), ""); */

			info("Created new node: %s with size (%s, %s)\n", this.node.name(),
				this.node.get("width"), this.node.get("height"));
		}

		public string name() { return this.node.name(); }
		public bool is_selected() { return this.selected; }
		public bool is_visible() { return this.child_widget.visible; }
		public GvcGraphMemberKind get_kind() { return GvcGraphMemberKind.NODE; }

		public void set_selected(bool val) { this.selected = val; }
		public GLib.Object get_object() { return this.child_widget; }

		/*** Get attribute from internal graphviz node */
		public string get_attribute(string a) {
			return this.node.get(a);
		}

		/*** Set attribute to internal graphviz node */
		public void set_attribute(string name, string val) {
			this.node.safe_set(name, val, "");
		}

		public Gtk.Allocation get_allocation(bool? update = false) {
			if ( this._alloc == null || update ) {
				string? val = null;
				val = this.node.get("width");
				double _w = ( val != null ) ? from_inches( double.parse(val) ) : 0;
				val = this.node.get("height");
				double _h = ( val != null ) ? from_inches( double.parse(val) ) : 0;
				val = this.node.get("pos");
				double _x = ( val != null && val.split(",").length == 2 )
								? double.parse( val.split(",")[0] ) : 0;
				double _y = ( val != null && val.split(",").length == 2 )
								? double.parse( val.split(",")[1] ) : 0;

				// if x and y is not calculated then add
				// node to center of graph
				if ( _x == _y == 0 ) {
					_x = this.layout.graph.get_width() / 2;
					_y = this.layout.graph.get_height() / 2;
				}

				this._alloc = {
					  (int) _x - ( (int) _w / 2 )
					, (int) _y - ( (int) _h / 2 )
					, (int) _w
					, (int) _h
				};
			}
			return this._alloc;
		}

		public void snapshot(Gtk.Snapshot snapshot,
							Pango.Context p_ctx,
							Gsk.Stroke stroke,
							Gsk.Shadow shadow,
							Gdk.RGBA color ) {

			float s = stroke.get_line_width ();

			Gsk.RoundedRect r = Gsk.RoundedRect().init_from_rect (
								this.get_allocation_rect(), 6);

			snapshot.append_border(
				r, { s, s, s, s }, { color, color, color, color } );

			snapshot.append_outset_shadow (
				r, color, shadow.dx , shadow.dy, 0, shadow.radius);
		}

	}


	public class GvcGraphEdge : GLib.Object, GvcMember, GvcGraphMember {

		public Gvc.Edge edge { get; set; }
		public string from { get; construct; }
		public string to { get; construct; }

		public bool visible { get; set; default = true; }
		public bool selected { get; set; }
		private Gtk.Allocation? _alloc = null;
		private Gsk.Path[] _paths = {};

		public GvcGraphEdge(Gvc.Edge edge, string from, string to) {
			GLib.Object( from: from, to: to );
			this.edge = edge;
		}

		public GvcGraphEdge.new_from_node(Gvc.Edge edge, GvcGraphNode from, GvcGraphNode to) {
			GLib.Object( from: from.name(), to: to.name() );
			this.edge = edge;

			// Bind visible widget attribute to hide edge when any of
			// the connected nodes are hidden.
			//
			// This part is currently commented out as binding on huge
			// graphs will waste processing resources for no good reason.
			//
			// from.child_widget.bind_property ( "visible",
			//	this, "visible", GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.DEFAULT );
			// to.child_widget.bind_property ("visible",
			//	this, "visible", GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.DEFAULT );
		}

		public string name() { return "%s -> %s".printf( from, to ); }
		public bool is_selected() { return this.selected; }
		public bool is_visible() { return this.visible; }
		public GvcGraphMemberKind get_kind() { return GvcGraphMemberKind.EDGE; }
		public GLib.Object get_object() { return this; }

		public void set_selected(bool val) { this.selected = val; }

		/*** Get attribute from internal graphviz edge */
		public string get_attribute(string a) {
			return this.edge.get(a);
		}

		/*** Set attribute to internal graphviz edge */
		public void set_attribute(string name, string val) {
			this.edge.safe_set(name, val, "");
		}

		public Gtk.Allocation get_allocation(bool? update = false) {

			if ( this._alloc == null || update ) {

				Gsk.PathBuilder builder = new Gsk.PathBuilder();
				Gsk.Path[] __paths = {};
				Gsk.Path __path;
				string[] xdots = {
					this.edge.get("_draw_"),
					this.edge.get("_hdraw_"),
					this.edge.get("_tdraw_")
				};

				foreach ( string xdot in xdots ) {
					if ( xdot == null )
						continue;
					string[] parts = xdot.split(" ");
					for ( int i = 0; i < parts.length; i++ ) {
						switch ( parts[i] ) {
							case "b": // B-Spine
							case "B": // Filled B-Spine
								i++;
								__path = build_bspline(
											parse_xdot_points(parts, ref i), ( parts[i-1] == "B" ) );
								__paths += __path;
								builder.add_path(__path);
								break;
							case "L": // Polyline
							case "P": // Filled Polygon
							case "p": // Polygon
								i++;
								__path = build_poly(
											parse_xdot_points(parts, ref i),
											// Close poly when polygon
											( parts[i-1] == "P" || parts[i-1] == "p" )
										);
								__paths += __path;
								builder.add_path(__path);
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

				this._paths = __paths;

				// Get bounds of the resulted path
				Graphene.Rect bounds;
				builder.to_path().get_bounds(out bounds);
				this._alloc = {
					(int) bounds.origin.x, (int) bounds.origin.y,
					(int) bounds.size.width, (int) bounds.size.height
				};

			}
			return this._alloc;
		}

		public void snapshot(Gtk.Snapshot snapshot,
							Pango.Context p_ctx,
							Gsk.Stroke stroke,
							Gsk.Shadow shadow,
							Gdk.RGBA color ) {

			foreach ( var path in this._paths ) {

				if ( ! path.is_empty() ) {
					// Stroke shape
					snapshot.append_stroke (path, stroke, color );

					// Fill
					if ( path.is_closed() )
						snapshot.append_fill (path, Gsk.FillRule.WINDING , color );
				}
			}
		}

	}

}
