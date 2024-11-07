/* application.vala
 *
 * Copyright 2024 @grey-land
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
namespace Gtkdot {

	public class SimpleEdge : Gtk.Widget, ISimpleMember {

		public static Gsk.Stroke stroke = new Gsk.Stroke(1);

		public string from {get;construct;}
		public string to {get;construct;}

		public GraphMemberKind kind { get; construct; }

		public Graphene.Point offset;
		public Gsk.Path path;
		public Graphene.Rect bounds { get; set; }

		construct {
			this.kind = GraphMemberKind.NODE;
			this.add_css_class ("edge");
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
				// , (int) this.bounds.size.width
				, 0
				// , (int) this.bounds.size.height
			};
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
				// If path is not closed ( usually the main curve path )
				// then add reverse path to be able to close the path
				// and behave as a shape that can be filled.
				if ( ! _path.is_closed() )
					builder.add_reverse_path( _path );
			}
			this.path = builder.to_path();
			this.path.get_bounds(out _bounds);
			this.bounds = _bounds;
			this.offset = _bounds.origin;
		}

		public SimpleEdge(string from, string to) {
			GLib.Object(from:from, to: to);
		}

		public SimpleEdge.from_widget(Gtk.Widget from, Gtk.Widget to) {
			GLib.Object( from: get_widget_id(from) , to: get_widget_id(to) );
		}

		public bool contains_selection (Graphene.Rect selection) {
			return
				this.path.in_fill( selection.origin, Gsk.FillRule.EVEN_ODD ) ||
				this.bounds.intersection(selection, null);
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
			/*
			Pango.Layout pl = new Pango.Layout( this.get_pango_context() );
			pl.set_alignment (Pango.Alignment.CENTER);
			pl.set_text( get_widget_id(this), -1 );
			int tw, th;
			pl.get_pixel_size (out tw, out th);
			snapshot.save();
			snapshot.translate( Graphene.Point().init(
					( this.bounds.size.width - (float) tw ) / 2,
					( this.bounds.size.height - (float) th ) / 2
				)
			);
			snapshot.append_layout(pl, this.get_color() );
			snapshot.restore();
			*/

			snapshot.save();
			snapshot.translate( Graphene.Point().init( - this.offset.x, - this.offset.y ) );
			snapshot.append_stroke( this.path, stroke, this.get_color() );
			snapshot.append_fill( this.path, Gsk.FillRule.EVEN_ODD, this.get_color() );
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
			if ( this.kind == GraphMemberKind.EDGE ) {
				child.add_css_class ("edge");
			} else {
				child.add_css_class ("node");
			}
		}

		public void set_selected( bool selected ) {
			if ( selected ) {
				this.child_widget.set_state_flags ( Gtk.StateFlags.SELECTED, false);
			} else {
				this.child_widget.unset_state_flags ( Gtk.StateFlags.SELECTED ) ;
			}
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
