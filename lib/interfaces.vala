
namespace Gtkdot {

	/**
	 * BaseGraph is the main class all Graph widgets should implement.
	 */
	public abstract class BaseGraph : Gtk.Widget {

		protected Gvc.Graph _graph;

		public string graph_id { get; construct; }
		public bool directed { get; construct; default = true; }
		public unowned Gvc.Graph get_graph() {
			return this._graph;
		}

		/**
		 * Iterates through child Gtk.Widgets and corresponding Gvc.Nodes.
		 *
		 * This works without keeping any reference between child widget and
		 * corresponding node because graphviz is guaranteed to visit the nodes
		 * of a graph, in their order of creation.
		 *
		 * Read more under [[https://graphviz.org/pdf/cgraph.pdf|Traversals Section]]
		 */
		public virtual void foreach_node(TraverseNode func, bool only_visible = false ) {

			unowned Gvc.Graph _graph = this.get_graph();

			Gtk.Widget child = this.get_first_child ();
			Gvc.Node node = _graph.get_first_node();

			while ( child != null && node != null ) {
				if ( child.should_layout() || ! only_visible ) {
					if ( func( _graph, child, node ) )
						break;
				}
				node = _graph.get_next_node(node);
				child = child.get_next_sibling();
			}
		}

		/*** Check whether widget exists in underline graph */
		public virtual bool node_exists( Gtk.Widget child ) {
			return ( this._graph.find_node( get_widget_id(child) ) != null );
		}

		/*** Add widget as node in underline graph */
		public virtual Gvc.Node add_node( Gtk.Widget child ) {

			if ( child.parent == null )
				child.set_parent(this);

			Gvc.Node n = this._graph.create_node( get_widget_id(child) );
			n.safe_set("label", "", "" );
			n.safe_set("shape", "box", "" );
			return n;
		}

		/*** Add edge connecting provided widgets in underline graph */
		public virtual Gvc.Edge? add_edge( Gtk.Widget from, Gtk.Widget to, string? name = null ) {

			Gvc.Node? _from = this._graph.find_node( get_widget_id(from) );
			Gvc.Node? _to = this._graph.find_node( get_widget_id(to) );

			if ( _from != null && _to != null )
				return this._graph.create_edge( _from, _to, name );
			else
				warning ("Failed to create edge");
			return null;
		}

		protected override void dispose () {
			var child = this.get_first_child ();
			while (child != null) {
				child.unparent ();
				child = this.get_first_child ();
			}
			base.dispose ();
		}

	}


	public interface ISimpleMember : GLib.Object {

		public abstract GraphMemberKind kind { get; construct; }

		public abstract bool is_selected();
		public abstract string get_id();
		public abstract void parse_xdot_attrs(string[] attrs);

		public abstract Gtk.Allocation compute_allocation();
		public abstract bool contains_selection (Graphene.Rect selection);
		public abstract void remove (Gvc.Graph g);

	}


}
