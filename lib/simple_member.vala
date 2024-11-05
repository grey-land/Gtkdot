namespace Gtkdot {

	public class SimpleEdge : Gtk.Widget, ISimpleMember {

		public string from {get;construct;}
		public string to {get;construct;}

		public GraphMemberKind kind { get; construct; }

		public Graphene.Point offset;
		public Gsk.Path[] paths;
		public Graphene.Rect bounds { get; set; } /*
			replace bounds,offset,paths with
		public Gsk.Path curve { get; set; }
		public Gsk.Path arrows { get; set; }
		*/

		construct {
			this.kind = GraphMemberKind.NODE;
			// this.add_css_class ("item");
		}

		public bool is_selected() {
			return Gtk.StateFlags.SELECTED in this.get_state_flags() ;
		}

		public string get_id () {
			return get_widget_id(this);
		}

		public Gtk.Allocation compute_allocation() {
			return {
				  (int) this.bounds.origin.x
				, (int) this.bounds.origin.y
				, 0
				, 0
			};
		}

		public void parse_xdot_attrs(string[] attrs) {
			Gsk.Path[] _paths = {};
			Gsk.PathBuilder builder = new Gsk.PathBuilder();
			Graphene.Rect _bounds;
			Gsk.Path _path;
			foreach ( string attr in attrs ) {
				if ( attr == null )
					continue;
				parse_xdot( attr, out _path);
				if ( _path == null )
					continue;
				_paths += _path;
				/*
				if ( attr == "_draw_" ) {
					unowned Gsk.PathPoint start;
					_path.get_start_point (out start);
					this.offset = start.get_position(_path);
				} else {
					builder.add_path( _path );
				}
				*/
				builder.add_path( _path );
			}
			_path = builder.to_path();
			_path.get_bounds(out _bounds);
			this.bounds = _bounds;
			this.paths = _paths;
			this.offset = _bounds.origin;
		}





		public SimpleEdge(string from, string to) {
			GLib.Object(from:from, to: to);
		}

		public SimpleEdge.from_widget(Gtk.Widget from, Gtk.Widget to) {
			GLib.Object( from: get_widget_id(from) , to: get_widget_id(to) );
		}

		public bool contains_selection (Graphene.Rect selection) {
			foreach ( var _path in this.paths ) {
				if ( _path.is_closed() && _path.in_fill( selection.origin, Gsk.FillRule.EVEN_ODD ) )
					return true;
			}
			return this.bounds.intersection(selection, null);
		}

		/**
		 * Remove Edge from given graph.
		 */
		public void remove(Gvc.Graph _graph) {
			Gvc.Edge _e;
			Gvc.Node? _n = _graph.find_node( this.from );
			if ( _n != null ) {
				for ( _e = _graph.get_first_edge_out(_n); _e != null;
						_e = _graph.get_next_edge_out(_e)) {
					if ( _e.name() == get_widget_id(this) && _e.head().name() == this.to ) {
						_graph.delete_object( _e );
						break;
					}
				}
			}
		}

		public override void snapshot(Gtk.Snapshot snapshot) {
			snapshot.save();
			snapshot.translate( Graphene.Point().init( - this.offset.x, - this.offset.y ) );
			print(@"EDGE: STATES.FLAGS: $( get_state_flags() )\n");
			foreach ( var _path in this.paths ) {
				snapshot.append_stroke( _path,
								SimpleGraph.stroke,
								this.is_selected()
									? SimpleGraph.selection_color
									: SimpleGraph.border_color
								// this.get_color()
							);
				if ( _path.is_closed() )
					snapshot.append_fill( _path,
								Gsk.FillRule.WINDING,
								this.is_selected()
									? SimpleGraph.selection_color
									: SimpleGraph.border_color
								// this.get_color()
							);
			}
			/*
			Pango.Layout pl = new Pango.Layout( this.get_pango_context() );
			pl.set_text( "[%s]".printf( get_widget_id(this) ), -1 );
			snapshot.append_layout(pl, color);
			*/
			snapshot.restore();
		}

	}



	public class SimpleMember : Gtk.LayoutChild, ISimpleMember {

		public GraphMemberKind kind {get; construct; }
		public Graphene.Rect bounds;

		public SimpleMember(Gtk.LayoutManager manager, Gtk.Widget child) {
			GLib.Object(layout_manager: manager,
						child_widget: child,
						kind: SimpleGraph.get_kind(child) );
		}

		public void set_selected( bool selected ) {
			if ( selected ) {
				this.child_widget.set_state_flags ( Gtk.StateFlags.SELECTED, false);
			} else {
				this.child_widget.unset_state_flags ( Gtk.StateFlags.SELECTED ) ;
			}
			this.child_widget.queue_draw();
		}

		public bool is_selected() {
			return Gtk.StateFlags.SELECTED in this.child_widget.get_state_flags() ;
		}

		public bool contains_selection (Graphene.Rect selection) {
			if ( this.kind == GraphMemberKind.EDGE ) {
				SimpleEdge se = this.child_widget as SimpleEdge;
				if ( se != null )
					return se.contains_selection( selection );
			}
			return this.bounds.contains_point(selection.origin) || selection.intersection(this.bounds, null);
		}

		public Gtk.Allocation compute_allocation() {
			SimpleEdge se = this.child_widget as SimpleEdge;
			return ( se != null )
				? se.compute_allocation()
				: Gtk.Allocation() {
						x = (int) this.bounds.origin.x,
						y = (int) this.bounds.origin.y,
						width = (int) this.bounds.size.width,
						height = (int) this.bounds.size.height,
					}
				;
		}

		public string get_id () {
			return get_widget_id(this.child_widget);
		}

		public void parse_xdot_attrs(string[] attrs) {
			if ( this.kind == GraphMemberKind.EDGE ) {
				SimpleEdge se = this.child_widget as SimpleEdge;
				if ( se != null )
					se.parse_xdot_attrs(attrs);
			} else {

				Gsk.PathBuilder builder = new Gsk.PathBuilder();
				Graphene.Rect _bounds;
				Gsk.Path _path;
				foreach ( string attr in attrs ) {
					if ( attr == null )
						continue;
					parse_xdot( attr, out _path);
					if ( _path == null )
						continue;
					builder.add_path( _path );
					// print("Node parse: %s =>\n\t%s\n", attr, _path.to_string() );
				}
				_path = builder.to_path();
				_path.get_bounds(out _bounds);
				this.bounds = _bounds;
			}
		}

		public void remove (Gvc.Graph g) {
			SimpleEdge se = this.child_widget as SimpleEdge;
			if ( se != null ) {
				se.remove(g);
			} else {
				Gvc.Node? _n = g.find_node( this.get_id() );
				if ( _n != null ) {
					g.delete_object( _n );
				}
			}
		}

	}


	/*
	public class SimpleNode : Gtk.Widget, ISimpleMember {

		public Gtk.Widget child { get; set; }
		public bool selected { get; set; }
		public GraphMemberKind kind { get; construct; }
		public Graphene.Rect bounds { get; set; }

		public bool is_selected() {
			return this.selected;
		}


		construct {
			this.selected = false;
			this.kind = GraphMemberKind.NODE;
		}

		public string get_id () {
			return get_widget_id(this);
		}

		public void parse_xdot_attrs(string[] attrs) {
			Gsk.PathBuilder builder = new Gsk.PathBuilder();
			Graphene.Rect _bounds;
			Gsk.Path _path;
			foreach ( string attr in attrs ) {
				if ( attr == null )
					continue;
				parse_xdot( attr, out _path);
				if ( _path == null )
					continue;
				builder.add_path( _path );
			}
			_path = builder.to_path();
			_path.get_bounds(out _bounds);
			this.bounds = _bounds;
		}

		public Gtk.Allocation compute_allocation() {
			return {
				  (int) this.bounds.origin.x
				, (int) this.bounds.origin.y
				, (int) this.bounds.size.width
				, (int) this.bounds.size.height
			};
		}

		public bool contains_selection (Graphene.Rect selection) {
			return this.bounds.contains_point(selection.origin) || selection.intersection(this.bounds, null);
		}

		public virtual void set_visibility (bool visible) {
			this.set_visible(visible);
		}

		public void remove(Gvc.Graph _graph) {
			Gvc.Node? _n = _graph.find_node( this.get_id() );
			if ( _n != null ) {
				_graph.delete_object( _n );
			}
		}

	}
	*/


}
