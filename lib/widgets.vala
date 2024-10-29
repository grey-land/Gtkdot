namespace Gtkdot {



	public class GraphView : Gtk.Widget {

		public double pad { get; set; default = 0.4; }
		public string rankdir { get; set; }
		public string extra { get; set; default = ""; }

		public bool draw_borders { get; set; default = true; }
		public bool draw_shadows { get; set; default = true; }

		public float border_stroke = 1;
		public Gdk.RGBA border_color = { 1, 1, 1, 1 };
		public Gdk.RGBA selection_color = { 1, 1, 1, 1 };
		public Gsk.Shadow shadow = {
				{ 1, 1, 1, 1 },
				1, 1, 1
			};

		private ulong pressed_sig = -1;
		private ulong motion_sig  = -1;
		private ulong release_sig = -1;

		private Graphene.Rect selection = {};
		private Gtk.GestureClick gc;
		private Gtk.EventControllerMotion cm;

		private GLib.List<uint> selected_nodes;
		private GLib.List<uint> selected_edges;

		public GraphLayoutManager layout {
			get { return layout_manager as GraphLayoutManager; }
		}

		construct {
			this.set_layout_manager( new GraphLayoutManager () );
			/*
			this.halign = Gtk.Align.CENTER;
			this.valign = Gtk.Align.CENTER;
			this.hexpand = true;
			this.vexpand = true;
			*/

			this.selected_nodes = new GLib.List<uint> ();
			this.selected_edges = new GLib.List<uint> ();
			this.cm = new Gtk.EventControllerMotion();
			this.gc = new Gtk.GestureClick();
			this.gc.set_propagation_phase ( Gtk.PropagationPhase.TARGET   );
			this.cm.set_propagation_phase ( Gtk.PropagationPhase.TARGET   );
			this.add_controller( this.gc );
			this.add_controller( this.cm );
		}

		public uint add_edge (uint start, uint end, string extra = "") {
			var e = new Edge.new_from_id( start, end );
			e.extra = extra;
			layout.edges.append( e );
			return -1;
		}

		public uint add_node (Gtk.Widget widget, string extra = "") {
			widget.set_parent (this);
			Node member = layout.get_member_from_widget(widget);
			// if ( member == null ) critical ("NO Node");
			member.extra = extra;
			return member.id;
		}


		public uint get_member_id_for_widget (Gtk.Widget widget) {
			Node member = layout.get_member_from_widget(widget);
			return member.id;
		}

		protected override void dispose () {
			var child = this.get_first_child ();
			while (child != null) {
				child.unparent ();
				child = this.get_first_child ();
			}
			base.dispose ();
		}

		public override void snapshot (Gtk.Snapshot snapshot) {

			assert_nonnull ( layout );

			// First we render graph renderings
			foreach ( var r in layout.renderings )
				r.render( snapshot, this.get_pango_context() );

			// If selection is active we draw the mouse selection rectangle
			if ( this.selection_is_active() ) {
				Gdk.RGBA sc = this.selection_color.copy ();
				sc.alpha = 0.05f;
				snapshot.append_color(sc, this.selection);
			}

			bool selected = false;
			float s = border_stroke;

			layout.nodes.@foreach ( (k, v) => {

				Node node = v;

				selected = node.is_selected();
				if ( ! selected && this.selection_is_active() ) {
					if ( node.contains ( this.selection.origin )
							|| this.selection.intersection( node.get_allocation_rect(), null) )
						selected = ! selected;
				}

				Gdk.RGBA c = selected ? this.selection_color : this.border_color;

				// Draw Node borders
				if ( this.draw_borders || selected )
					snapshot.append_border(
						node.get_rounded_border( s, 6 ),
						// { border_stroke, border_stroke, border_stroke, border_stroke },
						{ s, s, s, s },
						{ c, c, c, c }
					);

				if ( this.draw_shadows )
					snapshot.append_outset_shadow (
						node.get_rounded_border( s, 6 ),
						c, shadow.dx , shadow.dy, 0, shadow.radius);

				this.snapshot_child( node.child_widget, snapshot );

			});

			for ( int i = 0; i < layout.edges.length(); i ++ ) {
				Edge e = layout.edges.nth_data(i);

				selected = e.is_selected();
				// selected = this.selected_edges.index(i) >= 0;

				if ( this.selection_is_active() ) {
					if ( e.contains ( this.selection.origin )
							|| this.selection.intersection( e.get_allocation_rect(), null) )
						selected = ! selected;
				}
				Gdk.RGBA c = selected ? this.selection_color : this.border_color;

				foreach ( var r in e.get_renderings() ) {
					r.render(snapshot, this.get_pango_context(), c, c);
				}

			}

			if ( this.selection_is_active() ) {
				snapshot.append_border(
					Gsk.RoundedRect().init_from_rect (this.selection, 0),
					{ border_stroke, border_stroke, border_stroke, border_stroke },
					{ this.selection_color, this.selection_color, this.selection_color, this.selection_color } );

			}
		}


		/*** Check whether selection is enabled */
		public bool selection_is_enabled() {
			return pressed_sig != -1;
		}

		/*** Check whether selection is currently active */
		public bool selection_is_active () {
			return ! this.selection.equal( Graphene.Rect.zero() ) ;
		}

		/*** Enable selection */
		public void enable_selection() {
			this.pressed_sig = this.gc.pressed.connect( selection_click_callback );
		}

		/*** Disable selection */
		public void disable_selection() {
			this.gc.disconnect(pressed_sig);
			this.pressed_sig = -1;
		}

		/*** Clear currently selected items */
		public void clear_selection () {

			// clear selection rect
			this.selection = Graphene.Rect.zero ();

			// clear selection flag on all members
			layout.edges.@foreach ( (v)=> {
				if ( v.is_selected() ) {
					v.set_selected(false);
				}
			});

			layout.nodes.@foreach ( (k,v)=> {
				Node node = v;
				if ( node.is_selected() ) {
					node.set_selected(false);
				}
			});

		}


		public void remove_selected () {

			for ( uint i = 0; i < layout.edges.length(); i ++ ) {
				Edge e = layout.edges.nth_data(i);
				if ( e.is_selected() ) {
					print("\tRemove edge ( %d -> %d )\n",
						(int) e.start,
						(int) e.end
						);
					layout.edges.remove(e);
					i --;
				}
			}

			var keys = layout.nodes.get_keys ();
			for ( uint i = 0; i < keys.length(); i ++ ) {
				uint k = keys.nth_data(i);
				Node node =  layout.nodes.get(k);

				if ( node.is_selected() ) {
					print("Remove Node => %d\n", (int) k );
					layout.nodes.remove (k);
					node.child_widget.unparent();
				}
			}

		}

		public signal void selection_started ();
		public signal void selection_finished () {
			this.selection = Graphene.Rect.zero ();
			this.queue_draw();
		}

		private void selection_click_callback (int n_press, double x, double y) {

			// clear selection on all members
			this.clear_selection();

			// assign origin from click.
			this.selection.origin = Graphene.Point().init( (float) x, (float) y );

			// signal that selection has started
			this.selection_started();

			this.motion_sig = this.cm.motion.connect( ( _x, _y )=>{
				this.selection.size = Graphene.Size().init(
										(float) _x - this.selection.origin.x ,
										(float) _y - this.selection.origin.y );
				this.queue_draw();
			});

			this.release_sig = this.gc.released.connect ( (_n, _x, _y) => {
				this.gc.disconnect( this.release_sig );
				this.cm.disconnect( this.motion_sig );

				uint[] selected_node_ids = {};


				var keys = layout.nodes.get_keys ();
				for ( uint i = 0; i < keys.length(); i ++ ) {
					uint k = keys.nth_data(i);
					Node node =  layout.nodes.get(k);

					if ( node.contains ( this.selection.origin )
						|| this.selection.intersection( node.get_allocation_rect(), null) ) {
						node.set_selected(true);
						selected_node_ids += k;
					}

				}
				/*
				layout.nodes.@foreach( (k,v)=>{
				// for ( int i = 0; i < layout.nodes.length(); i ++ ) {
					// Node node = layout.nodes.nth_data(i);
					Node node = v;
					if ( node.contains ( this.selection.origin )
						|| this.selection.intersection( node.get_allocation_rect(), null) ) {
						node.set_selected(true);
						selected_node_ids += k;
					}
				// }
				});
				*/


				for ( int i = 0; i < layout.edges.length(); i ++ ) {
					Edge e = layout.edges.nth_data(i);

					if (e.contains ( this.selection.origin ) ||
						this.selection.intersection( e.get_allocation_rect(), null) ) {

						e.set_selected(true);

					} else {
						for ( int j = 0; j < selected_node_ids.length; j ++ ) {
							if ( e.start == selected_node_ids[j] || e.end == selected_node_ids[j] ) {
								e.set_selected(true);
							}
						}
					}
				}

				print("Selected -> nodes:%d edges:%d\n",
					(int) this.selected_nodes.length(),
					(int) this.selected_edges.length()
				);
				this.selection_finished();
			});

			this.queue_draw();

		}

	}


}
