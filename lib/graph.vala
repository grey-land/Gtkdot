
namespace Gtkdot {

	public class Graph : Gtk.Widget {

		public string title { get; set; default = ""; }
		public GraphLayout layout {
			get { return layout_manager as GraphLayout; }
		}

		private Graphene.Rect selection = {};
		private Gtk.GestureClick gc;
		private Gtk.EventControllerMotion cm;
		private ulong pressed_sig = -1;
		private ulong motion_sig  = -1;
		private ulong release_sig = -1;

		public Gdk.RGBA bg_color = { 1, 1, 1, 1 };
		public Gdk.RGBA border_color = { 0, 0, 0, 1 };
		public Gdk.RGBA selection_color = { 1, 0, 0, 1 };
		public Gdk.RGBA selection_fill_color = { 1, 0, 0, 0.1f };

		public Gsk.Shadow shadow = {
				{ 0.5f, 0.5f, 0.5f, 1 },
				1, 1, 1
			};
		public Gsk.Stroke stroke;

		construct {
			// set layout manager
			this.set_layout_manager( new GraphLayout () );
			this.layout.set_defaults();

			this.cm = new Gtk.EventControllerMotion();
			this.gc = new Gtk.GestureClick();
			this.gc.set_propagation_phase ( Gtk.PropagationPhase.TARGET   );
			this.cm.set_propagation_phase ( Gtk.PropagationPhase.TARGET   );
			this.add_controller( this.gc );
			this.add_controller( this.cm );

			this.stroke = new Gsk.Stroke(1);
			this.bg_color.parse("#dddddd");

			/*
			this.border_color.parse("#6F4E37");
			this.shadow.color.parse("#9d8b7c");
			this.selection_color.parse("#cb4335");
			this.bg_color.parse("#d5d0cc");
			this.stroke.set_line_cap( Gsk.LineCap.ROUND );
			this.stroke.set_line_join( Gsk.LineJoin.ROUND );
			*/
			// this.enable_selection();
		}

		public void add_node( Gtk.Widget child ) {
			child.set_parent(this);
			this.layout.get_node(child);
		}

		public void add_edge( Gtk.Widget from, Gtk.Widget to ) {
			this.layout.add_edge(from, to);
		}

		protected override void dispose () {
			var child = this.get_first_child ();
			while (child != null) {
				child.unparent ();
				child = this.get_first_child ();
			}
			base.dispose ();
		}

		public override void snapshot( Gtk.Snapshot snapshot ) {

			info("Graph Snapshot requested \n");

			// Apply background
			snapshot.append_color(this.bg_color,
				Graphene.Rect().init(
					//  0
					  - this.margin_start
					// , 0
					, - this.margin_top
					, this.get_width()  + this.margin_start + this.margin_end
					, this.get_height() + this.margin_top + this.margin_bottom
				)
			);

			// Loop through members and draw edges and widget borders
			layout.foreach_member( ( member ) => {

				if ( member.is_visible() ) {
					bool selected = member.is_selected();

					// process selection
					if ( ! selected && this.selection_is_active() )
						selected = member.contains_selection(selection);

					member.snapshot( snapshot, this.get_pango_context(),
								this.stroke, this.shadow, selected
									? this.selection_color
									: this.border_color );
				}
				return false;
			});

			// if selection is active fill selection rectangle
			if ( this.selection_is_active() )
				snapshot.append_color(this.selection_fill_color, this.selection);

			// draw actual widgets
			base.snapshot(snapshot);

			// if selection is active stroke selection rectangle
			if ( this.selection_is_active() )
				snapshot.append_border(
					Gsk.RoundedRect().init_from_rect (this.selection, 0),
					{ stroke.get_line_width(),
						stroke.get_line_width(),
						stroke.get_line_width(),
						stroke.get_line_width() },
					{ this.selection_color,
						this.selection_color,
						this.selection_color,
						this.selection_color });
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
		}

		/*** Disable selection */
		public void disable_selection() {
			this.gc.disconnect(pressed_sig);
			this.pressed_sig = -1;
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
			this.selection.origin = Graphene.Point().init( (float) x, (float) y );

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
				this.layout.apply_selection( this.selection );

				// clear selection
				this.selection = Graphene.Rect.zero ();

				// signal that selection finished - will request redraw
				this.selection_finished();

				this.queue_draw();

			});

		}

	}

}
