with (import <nixpkgs> {
	config.allowUnfree = true;
});

let
	# Enable vala graphviz feature
	valaGviz = vala.override { withGraphviz = true; };
in

mkShell {

	buildInputs = [

		# Build requirements
		meson
		ninja # meson requirement
		cmake
		pkg-config

		# vala
		valaGviz

		# project requirements
		glib
		gobject-introspection
		graphviz
		gtk4

		stdenv.cc.cc.lib

	];

	shellHook = ''
		export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
			pkgs.stdenv.cc.cc
		]}
	'';

	# Setup meson
	# -----------
	# meson setup --prefix ~/.meson-cellini-build localdir

	# Compile everything or single targets
	# ------------------------------------
	# meson compile -C localdir
	#
	# meson compile -C localdir cellini-cli
	# meson compile -C localdir cellini-typelib
	# meson compile -C localdir cellini-map
	# meson compile -C localdir cellini-resource

	# Install and export variables to find required libs
	# --------------------------------------------------
	# meson install -C localdir/
	# export PATH=$PATH:$HOME/.meson-cellini-build/bin
	# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/.meson-cellini-build/lib/
	# export GI_TYPELIB_PATH=$GI_TYPELIB_PATH:$HOME/.meson-cellini-build/lib/girepository-1.0

	# Enjoy
	# -----
	# cellini-cli
	# cellini-resource
	# cellini-annotator
	# cellini-map
}
