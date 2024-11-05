/* libgvc.vapi
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
 * ----------------------------------------------------------------------
 *
 * This is Vala API file (.vapi) exposing graphviz functionality to vala
 * programming language. It extends the official libgvc.vapi file in following ways:
 * 1. keeps only cgraph functionality (  #if WITH_CGRAPH ... )
 * 2. adds cgraph.h header to be able to expose relevant functions.
 * 3. add following extra functions
 *  - Gvc.object_kind
 *  - Gvc.object_copy
 *  - Edge.name
 *  - Edge.tail
 *  - Edge.head
 *  - Graph.n_nodes
 *  - Graph.n_edges
 *  - Graph.n_subgraphs
 *  - Graph.delete_object
 *  - Graph.contains_object
 *  - Graph.get_first_edge_out
 *  - Graph.get_next_edge_out
 *  - Graph.get_first_edge_in
 *  - Graph.get_next_edge_in
 *
 * Official vapi: [[https://gitlab.gnome.org/GNOME/vala/-/blob/84bc17f940e377a0a3c09383ba16d471913a5571/vapi/libgvc.vapi]]
 */

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "gvc.h,cgraph.h")]
namespace Gvc {

	[CCode (cname = "agobjkind")]
	public int object_kind ( void *obj );

	[CCode (cname = "agcopyattr")]
	public int object_copy (void *src, void* tgt);

	[CCode (cname = "aginitlib")]
	public void initlib ( size_t graphinfo, size_t nodeinfo, size_t  edgeinfo);

	[CCode (cname = "aginit")]
	public void init (Graph g, int kind, char[] rec_name, bool move_to_front);

	[SimpleType]
	[CCode (cname = "Agdesc_t")]
	public struct Desc {
	}

	public Desc Agdirected; // Desc.DIRECTED | Desc.MAINGRAPH;
	public Desc Agstrictdirected; //  Desc.DIRECTED | Desc.STRICT | Desc.MAINGRAPH;
	public Desc Agundirected; // Desc.MAINGRAPH;
	public Desc Agstrictundirected; // Desc.STRICT | Desc.MAINGRAPH;

	[CCode (cname = "agerrlevel_t", cprefix = "", has_type_id = false)]
	public enum ErrorLevel {
		AGWARN,
		AGERR,
		AGMAX,
		AGPREV
	}

	[Compact]
	[CCode (cname = "GVC_t", free_function = "gvFreeContext")]
	public class Context {
		[CCode (cname = "gvContext")]
		public Context ();

		[CCode (cname = "gvParseArgs")]
		public int parse_args ( [CCode (array_length_pos = 0.9)] string[] argv );

		[CCode (cname = "gvLayout")]
		public int layout (Graph graph, [CCode (type = "char*")] string layout_engine);

		[CCode (cname = "gvFreeLayout")]
		public int free_layout (Graph graph);

		[CCode (cname = "gvRender")]
		public int render (Graph graph, [CCode (type = "char*")] string file_type, GLib.FileStream? file);

		[CCode (cname = "gvRenderFilename")]
		public int render_filename (Graph graph, [CCode (type = "char*")] string file_type, [CCode (type = "char*")] string filename);

		[CCode (cname = "gvLayoutJobs")]
		public int layout_jobs (Graph graph);

		[CCode (cname = "gvRenderJobs")]
		public int render_jobs (Graph graph);

		[CCode (cname = "gvRenderData")]
		public int render_data (Graph graph, [CCode (type = "char*")] string file_type, [CCode (array_length_type = "unsigned int", type = "char**")] out uint8[] output_data);
	}

	[Compact]
	[CCode (cname = "Agnode_t", ref_function = "", unref_function = "", free_function = "")]
	public class Node {

		[CCode (cname = "agnameof")]
		public unowned string name ();

		[CCode (cname = "agget")]
		public unowned string? get ([CCode (type = "char*")] string attribute_name);

		[CCode (cname = "agset")]
		public int set ([CCode (type = "char*")] string attribute_name, [CCode (type = "char*")] string attribute_value);

		[CCode (cname = "agsafeset")]
		public void safe_set ([CCode (type = "char*")] string attribute_name, [CCode (type = "char*")] string attribute_value, [CCode (type = "char*")] string? default_value);

	}

	[Compact]
	[CCode (cname = "Agedge_t", ref_function = "", unref_function = "", free_function = "")]
	public class Edge {

		[CCode (cname = "agget")]
		public unowned string? get ([CCode (type = "char*")] string attribute_name);

		[CCode (cname = "agset")]
		public int set ([CCode (type = "char*")] string attribute_name, [CCode (type = "char*")] string attribute_value);

		[CCode (cname = "agsafeset")]
		public int safe_set ([CCode (type = "char*")] string attribute_name, [CCode (type = "char*")] string attribute_value, [CCode (type = "char*")] string? default_value);

		[CCode (cname = "agnameof")]
		public unowned string name ();

		[CCode (cname = "agtail")]
		public Node tail ();

		[CCode (cname = "aghead")]
		public Node head ();
	}

	[Compact]
	[CCode (cname = "Agraph_t", free_function = "agclose")]
	public class Graph {

		[CCode (cname = "agopen")]
		public Graph ([CCode (type = "char*")] string graph_name, Desc desc, int disc = 0);

		[CCode (cname = "agread")]
		public static Graph read (GLib.FileStream file);

		[CCode (cname = "agmemread")]
		public static Graph read_string (string str);

		[CCode (cname = "agnode")]
		public unowned Node create_node ([CCode (type = "char*")] string node_name, int createflag = 1);

		[CCode (cname = "agedge")]
		public unowned Edge create_edge (Node from, Node to, string? name = null, int createflag = 1);

		[CCode (cname = "agfindedge")]
		public unowned Edge? find_edge (Node from, Node to);

		[CCode (cname = "agsubg")]
		public unowned Graph create_subgraph ([CCode (type = "char*")] string? name, int createflag = 1);

		[CCode (cname = "agfindsubg")]
		public unowned Graph? find_subgraph ([CCode (type = "char*")] string name);

		[CCode (cname = "agidsubg")]
		public unowned Graph create_subgraph_id (ulong id, int createflag = 1);

		[CCode (cname = "agfstsubg")]
		public unowned Graph? get_first_subgraph ();

		[CCode (cname = "agnxtsubg")]
		public unowned Graph? get_next_subgraph ();

		[CCode (cname = "agparent")]
		public unowned Graph? get_parent_graph ();

		[CCode (cname = "agdelsubg")]
		public int delete_subgraph (Graph subgraph);

		[CCode (cname = "agfindnode")]
		public unowned Node? find_node ([CCode (type = "char*")] string node_name);

		[CCode (cname = "agfstnode")]
		public unowned Node? get_first_node ();

		[CCode (cname = "agnxtnode")]
		public unowned Node? get_next_node (Node node);

		[CCode (cname = "agget")]
		public unowned string? get ([CCode (type = "char*")] string attribute_name);

		[CCode (cname = "agset")]
		public int set ([CCode (type = "char*")] string attribute_name, [CCode (type = "char*")] string attribute_value);

		[CCode (cname = "agsafeset")]
		public int safe_set ([CCode (type = "char*")] string attribute_name, [CCode (type = "char*")] string attribute_value, [CCode (type = "char*")] string? default_value);

		[CCode (cname = "AG_IS_DIRECTED")]
		public bool is_directed ();

		[CCode (cname = "AG_IS_STRICT")]
		public bool is_strict ();

		[CCode (cname = "agnnodes")]
		public int n_nodes ();

		[CCode (cname = "agnedges")]
		public int n_edges ();

		[CCode (cname = "agnsubg")]
		public int n_subgraphs ();

		[CCode (cname = "agdelete")]
		public int delete_object ( void *obj );

		[CCode (cname = "agcontains")]
		public int contains_object ( void *obj );

		[CCode (cname = "agfstout")]
		public unowned Edge? get_first_edge_out ( Node e );

		[CCode (cname = "agnxtout")]
		public unowned Edge? get_next_edge_out ( Edge e );

		[CCode (cname = "agfstin")]
		public unowned Edge? get_first_edge_in ( Node e );

		[CCode (cname = "agnxtin")]
		public unowned Edge? get_next_edge_in ( Edge e );

		// [CCode (cname = "agidnode")]
		// public unowned Node create_node_id (uint64 id, int createflag = 1);

		// [CCode (cname = "agidedge")]
		// public unowned Edge create_edge_id (Node from, Node to, uint64 id, int createflag = 1);

		// [CCode (cname = "agfindnode_by_id")]
		// public unowned Node? find_node_id (uint64 id);

		// [CCode (cname = "agfindedge_by_id")]
		// public unowned Edge? find_edge_id (Node from, Node to, uint64 id);

	}

	[CCode (cname = "char", copy_function = "agdupstr_html", free_function = "agstrfree")]
	public class HtmlString : string {
		[CCode (cname = "agstrdup_html")]
		public HtmlString (string markup);
	}

	[CCode(cprefix = "ag")]
	namespace Error {
		[CCode (cname = "agerrno")]
		public static ErrorLevel errno;

		[CCode (cname = "agerr")]
		[PrintfFormat]
		public static int error (ErrorLevel level, string fmt, ...);

		[CCode (cname = "agerrors")]
		public static int errors ();

		[CCode (cname = "agseterr")]
		public static void set_error (ErrorLevel err);

		[CCode (cname = "aglasterr")]
		public static string? last_error ();

		[CCode (cname = "agerrorf")]
		[PrintfFormat]
		public static void errorf (string format, ...);

		[CCode (cname = "agwarningf")]
		[PrintfFormat]
		void warningf (string fmt, ...);
	}

}

