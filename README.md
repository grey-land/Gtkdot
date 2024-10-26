# gtkdot

An experimental graph library for Gtk 4 using Graphviz.

Graphs are complex beasts. The complexity arises from the laying out algorithm that
allocates the position and size for nodes and edges included in the graph, especially
when the graph contains thousands of nodes and edges. **Grkdot** library reuses the 
*holy grail of graphs*, aka Graphviz, to layout Gtk Widgets as graphs.
