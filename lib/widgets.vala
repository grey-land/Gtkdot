namespace Gtkdot {

	/**
	 * Edge class contain information about edges.
	 */
	protected class Edge : Gtk.Widget, GraphMember {

		protected Rendering[] renderings = {};

		public static Gdk.RGBA selected_color = { 0, 1, 1, 1 };

		private int idx;
		private bool selected;
		private string extra;
		private int head;
		private int tail;
		// private Rendering[] shapes;

		public Edge ( int idx, int head, int tail, string extra ) {
			this.idx = idx;
			this.head = head;
			this.tail = tail;
			this.extra = extra;
		}

		public int get_head() { return head; }
		public int get_tail() { return tail; }

		public bool get_selected() { return selected; }
		public void set_selected(bool val) {
			selected = val;
		}

		protected Rendering[] get_renderings() {
			return renderings;
		}

		protected void set_renderings( Rendering[] renderings ) {
			this.renderings = renderings;
		}

		public string get_dot_id () {
			return "e%d".printf(this.idx);
		}

		public string to_dot () {
			return "n%d -> n%d [ id=\"%s\" label=\"%s\" %s ];".printf( this.tail, this.head, this.get_dot_id(), this.get_dot_id(), this.extra );
		}

		/*** Check whether edge contains given point
		public override bool contains ( Graphene.Point point ) {
			foreach ( var r in this.renderings ) {
				if ( (
					// We use only arrow and text
					// not curve.
					r.x_dot == "_ldraw_"  ||
					r.x_dot == "_hdraw_"  ||
					r.x_dot == "_tdraw_"  ||
					r.x_dot == "_hldraw_" ||
					r.x_dot == "_tldraw_"
				) && r.contains(point) )
				return true;
			}
			return false;
		}
		 */

		public override void render (Gtk.Snapshot snapshot) {
			foreach ( var r in this.renderings ) {
				if ( selected ) {
					if ( r.x_dot == "_draw_" || r.x_dot == "_hdraw_" || r.x_dot == "_tdraw_" )
						r.render(snapshot, selected_color, selected_color);
					else
						r.render(snapshot, null, null);
				} else {
					r.render(snapshot, null, null);
				}
			}
		}
	}



	public class GraphView : Gtk.Widget {

		construct {
			this.set_layout_manager( new GraphLayoutManager () );
			this.halign = Gtk.Align.CENTER;
			this.valign = Gtk.Align.CENTER;

			Gtk.GestureClick gc = new Gtk.GestureClick();
			gc.pressed.connect( gesture_click_pressed );
			this.add_controller(gc);
		}

		public void add_edge (int head, int tail, string extra = "") {
			var layout = (GraphLayoutManager) layout_manager;
			layout.add_edge ( head, tail, extra);
		}

		public void add_node (Gtk.Widget widget) {
			widget.set_parent (this);
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
			var layout = (GraphLayoutManager) layout_manager;
			// snapshot.save();
			// snapshot.translate( layout.compute_offset() );
			layout.render( snapshot );
			base.snapshot(snapshot);
			// snapshot.restore();
		}

		private void gesture_click_pressed (int n_press, double x, double y) {
			var layout = (GraphLayoutManager) layout_manager;
			var edge = layout.edge_contains( Graphene.Point().init( (float) x,  (float) y )  ) ;
			if ( edge != null ) {
				edge.set_selected( ! edge.get_selected() );
				print("Set edge as selected : %s\n", edge.to_dot() );
				this.queue_draw();
			}
		}

	}


}
