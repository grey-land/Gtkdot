
void main (string[] args) {
	GLib.Test.init (ref args);
	TestLibGvcVapi.add_tests();
	GLib.Test.run ();
}
