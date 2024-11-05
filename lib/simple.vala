namespace Gtkdot {

	public class SimpleGraph : BaseGraph {

		public static Gdk.RGBA selection_color = { 1, 0, 0, 1 };
		public static Gdk.RGBA selection_fill_color = { 1, 0, 0, 0.1f };
		public static Gsk.Stroke stroke = new Gsk.Stroke(1);

		public static Gdk.RGBA border_color = { 0, 0, 0, 1 };
		public static Gsk.Shadow shadow = {
				{ 0.5f, 0.5f, 0.5f, 1 },
				1, 1, 1
			};

		public static GraphMemberKind get_kind ( Gtk.Widget widget ) {
			return widget.get_type().is_a( typeof(SimpleEdge) )
				? GraphMemberKind.EDGE
				: GraphMemberKind.NODE
				;
		}

		public SimpleLayout layout { get { return layout_manager as SimpleLayout; } }
		public uint n_members { get { return this.members.length; } }

		protected GLib.HashTable<string,Gtk.Widget*> members;

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
			return this.layout.create_layout_child( this, child ) as SimpleMember;
		}

		public SimpleMember? connect_edge( SimpleEdge se ) {
			Gvc.Node? _from = _graph.find_node( se.from );
			Gvc.Node? _to = _graph.find_node( se.to );
			if ( _from != null && _to != null ) {
				_graph.create_edge( _from, _to, get_widget_id(se) );
				if ( se.parent == null )
					se.set_parent(this);
				Gtk.Widget* _ptr = se;
				this.members.insert( get_widget_id(se), _ptr );
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

			/* Apply background
			snapshot.append_color(SimpleGraph.bg_color,
				Graphene.Rect().init(
					0, 0, this.get_width(), this.get_height()
				)
			); */

			base.snapshot(snapshot);

			// Draw selection box if selection is active
			if ( this.selection_is_active() ) {
				// fill selection box
				snapshot.append_color( SimpleGraph.selection_fill_color, this.selection);
				// stroke selection box
				snapshot.append_border(
					Gsk.RoundedRect().init_from_rect (this.selection, 0),
					{ stroke.get_line_width(),
						stroke.get_line_width(),
						stroke.get_line_width(),
						stroke.get_line_width() },
					{ SimpleGraph.selection_color,
						SimpleGraph.selection_color,
						SimpleGraph.selection_color,
						SimpleGraph.selection_color });
			}

			this.members.@foreach( (k, child) => {

				if ( child->should_layout() ) {

					SimpleMember lm = this.layout.get_member(child);

					if ( this.selection_is_active() )
						lm.set_selected( lm.contains_selection(selection) );

					if ( lm.kind == GraphMemberKind.NODE ) {
						Gdk.RGBA c = lm.is_selected()
											? SimpleGraph.selection_color
											: SimpleGraph.border_color;
						Gsk.RoundedRect _r = Gsk.RoundedRect().init_from_rect( lm.bounds, 4)
												.shrink(
													  0 // - stroke.get_line_width()
													, SimpleGraph.stroke.get_line_width()
													, 0 // - stroke.get_line_width()
													, - SimpleGraph.stroke.get_line_width()
												);
						// Border
						snapshot.append_border(_r, {
								  stroke.get_line_width()
								, stroke.get_line_width()
								, stroke.get_line_width()
								, stroke.get_line_width()
							}, { c, c, c, c });

						// Shadow
						snapshot.append_outset_shadow (_r,
							SimpleGraph.shadow.color,
							SimpleGraph.shadow.dx, SimpleGraph.shadow.dy, 0, SimpleGraph.shadow.radius);

					}
				}
			});

		}

	}



	/**
	 * SimpleLayout extexts LightLayout managing both nodes and edges as Gtk.Widgets.
	 */
	public class SimpleLayout : LightLayout {

		public SimpleGraph parent {
			get { return this.get_widget() as SimpleGraph; }
		}

		protected override void root () {
			if ( this.parent == null ) {
				critical("SimpleLayout should contain SimpleGraph widget." );
				return;
			}
			Gtk.Widget child = this.parent.get_first_child ();
			while ( child != null ) {
				switch ( SimpleGraph.get_kind(child) ) {
					case GraphMemberKind.NODE:
						this.parent.add_full_node(child);
						break;
					default:
						this.parent.connect_edge( child as SimpleEdge );
						break;
				}
				child = child.get_next_sibling();
			}
		}

		/*** Get SimpleMember for given widget */
		public SimpleMember get_member ( Gtk.Widget widget ) {
			return this.get_layout_child( widget ) as SimpleMember;
		}

		public override Gtk.LayoutChild create_layout_child (Gtk.Widget container, Gtk.Widget child) {
			return new SimpleMember(this, child);
		}

		public override void allocate (Gtk.Widget widget, int width, int height, int baseline) {

			unowned Gvc.Graph _graph = this.parent.get_graph();

			_graph.safe_set("_draw_", "", "");
			_graph.safe_set("size",
					"%g,%g".printf(
						points_to_inches( (double) width ), points_to_inches( (double) height )
						), "");

			debug("Diagram: %s\n",
				(string) render_diagram(_graph, this.layout_engine, "xdot") );

			SimpleMember member;
			Gvc.Node? n = null;
			Gvc.Edge? e = null;
			for ( n = _graph.get_first_node(); n != null; n = _graph.get_next_node(n) ) {

				member = this.get_member( this.parent.get_member( n.name() ) );
				// member.allocate_node( n, baseline );
				member.parse_xdot_attrs({ n.get("_draw_") });
				member.child_widget.allocate_size( member.compute_allocation(), baseline );


				for (e = _graph.get_first_edge_out(n); e != null; e = _graph.get_next_edge_out(e)) {
					member = this.get_member( this.parent.get_member( e.name() ) );
					// member.allocate_edge( e, baseline );
					member.parse_xdot_attrs({ e.get("_draw_"), e.get("_tdraw_"), e.get("_hdraw_")  });
					member.child_widget.allocate_size( member.compute_allocation(), baseline );

					// Force redraw all edges as in any new allocation the
					// edges' position and size changes.
					member.child_widget.queue_draw();
				}

			}

			if ( enable_signals )
				this.layout_updated();

		}

	}


}
