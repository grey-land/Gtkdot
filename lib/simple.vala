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

	public class SimpleGraph : BaseGraph {

		public static Gsk.Stroke stroke = new Gsk.Stroke(1);

		public static GraphMemberKind get_kind ( Gtk.Widget widget ) {
			return widget.get_type().is_a( typeof(SimpleEdge) )
				? GraphMemberKind.EDGE
				: GraphMemberKind.NODE
				;
		}

		public unowned Gvc.Graph graph { get { return this._graph; } }
		public GLib.HashTable<string,Gtk.Widget*> members;
		public uint n_members { get { return this.members.length; } }
		public SimpleLayout layout { get { return layout_manager as SimpleLayout; } }

		public signal void edge_added( Gtk.Widget child, Gvc.Edge edge );
		public signal void node_added( Gtk.Widget child, Gvc.Node node );

		private Graphene.Rect selection = {};
		private Gtk.GestureClick gc;
		private Gtk.EventControllerMotion cm;
		private ulong pressed_sig = -1;
		private ulong motion_sig  = -1;
		private ulong release_sig = -1;

		construct {
			this.set_layout_manager( new SimpleLayout () );
			this._graph = new Gvc.Graph (
							this.graph_id != null
								? this.graph_id
								: get_widget_id(this),
							this.directed
								? Gvc.Agdirected
								: Gvc.Agundirected );

			this.members = new GLib.HashTable<string,Gtk.Widget*>(str_hash, str_equal);

			this.cm = new Gtk.EventControllerMotion();
			this.gc = new Gtk.GestureClick();
			this.gc.set_propagation_phase ( Gtk.PropagationPhase.TARGET );
			this.cm.set_propagation_phase ( Gtk.PropagationPhase.TARGET );
			this.add_css_class ("graph");
		}

		public Gtk.Widget get_member ( string id ) {
			return this.members.@get( id );
		}

		public SimpleMember? add_full_edge( Gtk.Widget from, Gtk.Widget to ) {
			SimpleEdge se = new SimpleEdge.from_widget(from, to);
			return this.connect_edge(se);
		}

		public SimpleMember add_full_node( Gtk.Widget child ) {
			Gvc.Node n = this.add_node(child);
			Gtk.Widget* _ptr = child;
			this.members.insert( n.name(), _ptr );
			this.node_added( child, n );
			return this.layout.create_layout_child( this, child ) as SimpleMember;
		}

		public SimpleMember? connect_edge( SimpleEdge se ) {
			Gvc.Node? _from = _graph.find_node( se.from );
			Gvc.Node? _to = _graph.find_node( se.to );
			if ( _from != null && _to != null ) {
				Gvc.Edge e = _graph.create_edge( _from, _to, get_widget_id(se) );
				// e.safe_set("arrowhead", "none", "");
				if ( se.parent == null )
					se.set_parent(this);
				Gtk.Widget* _ptr = se;
				this.members.insert( get_widget_id(se), _ptr );
				this.edge_added( se, e );
				return this.layout.create_layout_child( this, se ) as SimpleMember;
			}
			warning ("Failed to connect edge");
			return null;
		}

		public override void foreach_node(TraverseNode func, bool only_visible = false ) {
			Gtk.Widget child = this.get_first_child ();
			Gvc.Node node = _graph.get_first_node();
			while ( child != null ) {
				if ( SimpleGraph.get_kind(child) == GraphMemberKind.NODE && ( child.should_layout() || ! only_visible ) ) {
					if ( func( _graph, child, node ) )
						break;
					node = _graph.get_next_node(node);
				}
				child = child.get_next_sibling();
			}
		}

		public void set_visibility (Gtk.Widget child, bool visible) {
			switch ( SimpleGraph.get_kind(child) ) {
				case GraphMemberKind.EDGE:
					child.set_visible(visible);
					break;
				case GraphMemberKind.NODE:
					Gvc.Node? n = _graph.find_node( get_widget_id(child) );
					if ( n != null ) {
						Gtk.Widget _e;
						Gvc.Edge e;
						for (e = _graph.get_first_edge_out(n); e != null; e = _graph.get_next_edge_out(e)) {
							_e = this.get_member( e.name() );
							_e.set_visible(visible);
						}
						for (e = _graph.get_first_edge_in(n); e != null; e = _graph.get_next_edge_in(e)) {
							_e = this.get_member( e.name() );
							_e.set_visible(visible);
						}
					}
					child.set_visible(visible);
					break;
				default:
					break;
			}
		}

		/*** Check whether selection is currently active */
		public bool selection_is_active () {
			return ! this.selection.equal( Graphene.Rect.zero() ) ;
		}

		/*** Check whether selection is enabled */
		public bool selection_is_enabled() {
			return pressed_sig != -1;
		}

		/*** Enable selection */
		public void enable_selection() {
			this.pressed_sig = this.gc.pressed.connect( selection_click_callback );
			this.add_controller( this.gc );
			this.add_controller( this.cm );
		}

		/*** Disable selection */
		public void disable_selection() {
			this.gc.disconnect( this.release_sig );
			this.cm.disconnect( this.motion_sig );
			this.gc.disconnect( this.pressed_sig );
			this.pressed_sig = -1;
			this.remove_controller( this.gc );
			this.remove_controller( this.cm );
		}

		public signal void selection_started () {}
		public signal void selection_finished () {
			// disconnect motion/release signal handlers
			this.gc.disconnect( this.release_sig );
			this.cm.disconnect( this.motion_sig );
		}

		private void selection_click_callback (int n_press, double x, double y) {

			// clear selection
			this.selection = Graphene.Rect.zero ();

			// assign selection origin from mouse position
			this.selection.origin = Graphene.Point().init(
				  (float) x // / this.get_scale_value(),
				, (float) y // / this.get_scale_value()
			);

			// On mouse move, update selection rectangle
			// and request to re-render widget for selection
			// to render selected nodes
			this.motion_sig = this.cm.motion.connect( ( _x, _y )=>{
				this.selection.size = Graphene.Size().init(
										(float) _x - this.selection.origin.x ,
										(float) _y - this.selection.origin.y );
				this.queue_draw();
			});

			// signal that selection started
			this.selection_started();

			// On mouse release
			this.release_sig = this.gc.released.connect ( (_n, _x, _y) => {

				// set selection flag on nodes/edges
				this.apply_selection( this.selection );

				// clear selection
				this.selection = Graphene.Rect.zero ();

				// signal that selection finished - will request redraw
				this.selection_finished();

				this.queue_draw();

			});

		}

		public void select_all() {
			SimpleMember lm;
			foreach ( string k in this.members.get_keys() ) {
				lm = this.layout.get_member(this.members.@get(k) );
				lm.set_selected( true );
			}
		}

		public void apply_selection( Graphene.Rect bounds ) {

			SimpleMember lm;

			string[] selected_nodes = {};

			foreach ( string k in this.members.get_keys() ) {

				lm = this.layout.get_member(this.members.@get(k) );
				if ( lm.child_widget.should_layout() ) {
					lm.set_selected( lm.contains_selection(bounds) );
					if ( lm.is_selected() && lm.kind == GraphMemberKind.NODE )
						selected_nodes += k;
				}
			}

			Gvc.Edge _e;
			Gvc.Node _n;
			foreach ( string selected_node in selected_nodes) {
				_n = _graph.find_node( selected_node );
				if ( _n == null )
					continue;

				for ( _e = _graph.get_first_edge_out(_n); _e != null; _e = _graph.get_next_edge_out(_e)) {
					lm = this.layout.get_member( this.members.@get( _e.name() ) );
					lm.set_selected(true);
				}

				for ( _e = _graph.get_first_edge_in(_n); _e != null; _e = _graph.get_next_edge_in(_e)) {
					lm = this.layout.get_member( this.members.@get( _e.name() ) );
					lm.set_selected(true);
				}
			}
		}

		public void remove_selected() {
			foreach ( string k in this.members.get_keys() ) {
				SimpleMember lm = this.layout.get_member(this.members.@get(k) );
				if ( lm != null && lm.is_selected() ) {
					lm.remove( _graph );
					lm.child_widget.unparent();
					this.members.remove(k);
				}
			}
		}

		public override void snapshot(Gtk.Snapshot snapshot) {

			if ( this.selection_is_active() ) {

				// Fill selection box if selection is active
				Gdk.RGBA sc = this.get_color().copy();
				sc.alpha = 0.2f;
				// fill selection box
				snapshot.append_color( sc, this.selection);

				// Iterate through visible widgets and set selection
				// flag based on current selection
				//
				// By setting selection flag we force widget
				this.members.@foreach( (k, child) => {
					if ( child->should_layout() ) {
						SimpleMember lm = this.layout.get_member(child);
						lm.set_selected( lm.contains_selection(selection) );
					}
				});

			}

			base.snapshot(snapshot);

			// Stroke selection box if selection is active
			if ( this.selection_is_active() )
				// stroke selection box
				snapshot.append_border(
					Gsk.RoundedRect().init_from_rect (this.selection, 0),
					{ stroke.get_line_width(),
						stroke.get_line_width(),
						stroke.get_line_width(),
						stroke.get_line_width() },
					{ this.get_color(),
						this.get_color(),
						this.get_color(),
						this.get_color() });

		}

	}

}

