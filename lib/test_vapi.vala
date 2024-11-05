
public class TestLibGvcVapi {

	// A4 size 	210 x 297 mm 	8.3 x 11.7 in
	public const double a4__w_mm = 210;
	public const double a4__h_mm = 297;
	public const double a4__w_in = 8.3;
	public const double a4__h_in = 11.7;

	public static void add_tests() {
		/*
		digraph GraphTest {
			graph [bb="0,0,81,180"];
			node [label="\N"];
			n1	[height=0.5, pos="54,162", shape=box, width=0.75];
			n2	[height=0.5, pos="27,90",  shape=box, width=0.75];
			n3	[height=0.5, pos="54,18",  shape=box, width=0.75];

			n1 -> n2	;
			n1 -> n3;
			n2 -> n3;
		}
		*/
		GLib.Test.add_func("/libgvc/vapi", ()=>{

			uint8[] ret = {};
			Gvc.Context ctx = new Gvc.Context();
			Gvc.Graph graph = new Gvc.Graph ("GraphTest", Gvc.Agdirected);

			graph.safe_set("size", "%g,%g".printf( a4__w_in, a4__h_in ), "" );
			graph.safe_set("scale", "2.0", "" );

			Gvc.Node[] nodes = {
				graph.create_node("n1"),
				graph.create_node("n2"),
				graph.create_node("n3")
			};

			nodes[0].safe_set("shape", "box", "");
			nodes[1].safe_set("shape", "box", "");
			nodes[2].safe_set("shape", "box", "");

			Gvc.Edge[] edges = {
				graph.create_edge( nodes[0], nodes[1], "e1" ),
				graph.create_edge( nodes[1], nodes[2], "e2" ),
				graph.create_edge( nodes[0], nodes[2], "e3" ),
			};

			// AGTYPE test
			assert_cmpint( Gvc.object_kind( graph ), GLib.CompareOperator.EQ, 0 );
			assert_cmpint( Gvc.object_kind( nodes[0] ), GLib.CompareOperator.EQ, 1 );
			assert_cmpint( Gvc.object_kind( edges[0] ), GLib.CompareOperator.EQ, 2 );

			// Edge functions
			assert_cmpstr( edges[0].tail().name(), GLib.CompareOperator.EQ, "n1" );
			assert_cmpstr( edges[0].head().name(), GLib.CompareOperator.EQ, "n2" );


			ctx.layout(graph, "dot");

			assert_cmpstr( graph.get("bb"), GLib.CompareOperator.EQ, "0 0 81 180" );
			assert_cmpstr( nodes[0].get("pos"), GLib.CompareOperator.EQ, null );
			assert_cmpstr( nodes[1].get("pos"), GLib.CompareOperator.EQ, null );
			assert_cmpstr( nodes[2].get("pos"), GLib.CompareOperator.EQ, null );

			ctx.render_data(graph, "dot", out ret);

			stderr.printf("Traversal\n");
			Gvc.Node? n = null;
			Gvc.Edge? e = null;
			for ( n = graph.get_first_node(); n != null; n = graph.get_next_node(n) ) {
				stderr.printf("\tnode: %s\n", n.name() );
				for (e = graph.get_first_edge_out(n); e != null; e = graph.get_next_edge_out(e)) {
					stderr.printf("\t\tedge: %s\n", e.name() );
				}
			}

			assert_cmpstr( graph.get("bb"), GLib.CompareOperator.EQ, "0,0,81,180" );
			assert_cmpstr( nodes[0].name(), GLib.CompareOperator.EQ, "n1" );
			assert_cmpstr( nodes[0].get("pos"), GLib.CompareOperator.EQ, "54,162" );
			assert_cmpstr( nodes[0].get("height"), GLib.CompareOperator.EQ, "0.5" );
			assert_cmpstr( nodes[0].get("width"), GLib.CompareOperator.EQ, "0.75" );

			assert_cmpstr( nodes[1].name(), GLib.CompareOperator.EQ, "n2" );
			assert_cmpstr( nodes[1].get("pos"), GLib.CompareOperator.EQ, "27,90" );
			assert_cmpstr( nodes[1].get("height"), GLib.CompareOperator.EQ, "0.5" );
			assert_cmpstr( nodes[1].get("width"), GLib.CompareOperator.EQ, "0.75" );

			assert_cmpstr( nodes[2].name(), GLib.CompareOperator.EQ, "n3" );
			assert_cmpstr( nodes[2].get("pos"), GLib.CompareOperator.EQ, "54,18" );
			assert_cmpstr( nodes[2].get("height"), GLib.CompareOperator.EQ, "0.5" );
			assert_cmpstr( nodes[2].get("width"), GLib.CompareOperator.EQ, "0.75" );

			ctx.free_layout(graph);


			assert_cmpint( graph.n_nodes(), GLib.CompareOperator.EQ, 3 );
			assert_cmpint( graph.n_edges(), GLib.CompareOperator.EQ, 3 );
			assert_cmpint( graph.n_subgraphs(), GLib.CompareOperator.EQ, 0 );

			stdout.printf("delete node\n");
			graph.delete_object( nodes[2] );
			assert_cmpint( graph.n_nodes(), GLib.CompareOperator.EQ, 2 );
			assert_cmpint( graph.n_edges(), GLib.CompareOperator.EQ, 1 );

			assert_cmpint( graph.contains_object(edges[0]), GLib.CompareOperator.EQ, 1 );
			assert_cmpint( graph.contains_object(edges[1]), GLib.CompareOperator.EQ, 0 );
			assert_cmpint( graph.contains_object(edges[2]), GLib.CompareOperator.EQ, 0 );

			stdout.printf("delete edge\n");
			graph.delete_object( edges[0] );
			assert_cmpint( graph.n_edges(), GLib.CompareOperator.EQ, 0 );

		});


		GLib.Test.add_func("/graph/resize", ()=>{

			uint8[] ret = {};
			Gvc.Context ctx;
			Gvc.Graph graph;
			Gvc.Node[] nodes;
			Gvc.Edge[] edges;

			// Create test diagram
			graph = new Gvc.Graph ("GraphTest", Gvc.Agdirected);
			nodes = {
				graph.create_node("n1"),
				graph.create_node("n2"),
				graph.create_node("n3")
			};
			edges = {
				graph.create_edge( nodes[0], nodes[1] ),
				graph.create_edge( nodes[1], nodes[2] ),
				graph.create_edge( nodes[0], nodes[2] ),
			};
			nodes[0].safe_set("shape", "box", "");
			nodes[1].safe_set("shape", "box", "");
			nodes[2].safe_set("shape", "box", "");

			ctx = new Gvc.Context();
			ctx.layout(graph, "dot");
			ctx.render_data(graph, "dot", out ret);
			stdout.printf("DIAGRAM WITHOUT SIZE :\n %s\n", (string) ret);

			assert_cmpstr( graph.get("bb"), GLib.CompareOperator.EQ, "0,0,81,180" );
			assert_cmpstr( nodes[0].name(), GLib.CompareOperator.EQ, "n1" );
			assert_cmpstr( nodes[0].get("pos"), GLib.CompareOperator.EQ, "54,162" );
			assert_cmpstr( nodes[0].get("height"), GLib.CompareOperator.EQ, "0.5" );
			assert_cmpstr( nodes[0].get("width"), GLib.CompareOperator.EQ, "0.75" );

			assert_cmpstr( nodes[1].name(), GLib.CompareOperator.EQ, "n2" );
			assert_cmpstr( nodes[1].get("pos"), GLib.CompareOperator.EQ, "27,90" );
			assert_cmpstr( nodes[1].get("height"), GLib.CompareOperator.EQ, "0.5" );
			assert_cmpstr( nodes[1].get("width"), GLib.CompareOperator.EQ, "0.75" );

			assert_cmpstr( nodes[2].name(), GLib.CompareOperator.EQ, "n3" );
			assert_cmpstr( nodes[2].get("pos"), GLib.CompareOperator.EQ, "54,18" );
			assert_cmpstr( nodes[2].get("height"), GLib.CompareOperator.EQ, "0.5" );
			assert_cmpstr( nodes[2].get("width"), GLib.CompareOperator.EQ, "0.75" );

			ctx.free_layout(graph);


			// Increase diagram size
			string graph_ratio = "fill";
			graph.safe_set("ratio", graph_ratio, "" );
			graph.safe_set("size", "%g,%g".printf( a4__w_in, a4__h_in ), "" );

			ctx = new Gvc.Context();
			ctx.layout(graph, "dot");
			ctx.render_data(graph, "dot", out ret);
			stdout.printf("DIAGRAM WITH SIZE :\n %s\n", (string) ret);

			assert_cmpstr( nodes[0].name(), GLib.CompareOperator.EQ, "n1" );
			assert_cmpstr( nodes[0].get("pos"), GLib.CompareOperator.EQ, "398.67,758" );
			assert_cmpstr( nodes[0].get("height"), GLib.CompareOperator.EQ, "0.5" );
			assert_cmpstr( nodes[0].get("width"), GLib.CompareOperator.EQ, "0.75" );

			assert_cmpstr( nodes[1].name(), GLib.CompareOperator.EQ, "n2" );
			assert_cmpstr( nodes[1].get("pos"), GLib.CompareOperator.EQ, "199.67,421" );
			assert_cmpstr( nodes[1].get("height"), GLib.CompareOperator.EQ, "0.5" );
			assert_cmpstr( nodes[1].get("width"), GLib.CompareOperator.EQ, "0.75" );

			assert_cmpstr( nodes[2].name(), GLib.CompareOperator.EQ, "n3" );
			assert_cmpstr( nodes[2].get("pos"), GLib.CompareOperator.EQ, "398.67,84" );
			assert_cmpstr( nodes[2].get("height"), GLib.CompareOperator.EQ, "0.5" );
			assert_cmpstr( nodes[2].get("width"), GLib.CompareOperator.EQ, "0.75" );

			ctx.free_layout(graph);

		});

	}

}
