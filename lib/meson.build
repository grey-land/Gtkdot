
gtkdot_deps = [

	# We make use of some Gsk components that are
	# available only from Gtk version 4.14 and above.
	dependency('gtk4', version: '>=  4.14'),

	# Graphviz ( currently use 12.1.2 )
	# should work for > 2.3 but not tested.
	dependency('libgvc', version: '>= 2.3' ),

]

gtkdot_conf_data = configuration_data()
gtkdot_conf_data.set('VERSION',  meson.project_version() )
gtkdot_config = configure_file(
	input: 'config.vala.meson',
	output: 'config.vala',
	configuration: gtkdot_conf_data)

gtkdot_sources = [
	'utils.vala',
	'member.vala',
	'layout.vala',
	'graph.vala',
]

gtkdot_sources += gtkdot_config

gtkdot_lib_inc = include_directories('.')

# build shared library
gtkdot_lib = shared_library('gtkdot-' + meson.project_version(),
	gtkdot_sources,
	vala_header: 'gtkdot.h',
	vala_vapi: 'gtkdot-' + meson.project_version() + '.vapi',
	vala_gir: 'Gtkdot-' + meson.project_version() + '.gir',
	vala_args: [
		# This flag is required to correctly link libgcv.vapi
		# with graphviz cgraph api.
		# see: https://gitlab.gnome.org/GNOME/vala/-/blob/main/vapi/libgvc.vapi
		'-D', 'WITH_CGRAPH'
	],
	dependencies: gtkdot_deps,
	include_directories: gtkdot_lib_inc,
	install: true,
	install_dir: [true, true, true, true])

# generate pkg-config for shared library
cellini_core_pkg = import('pkgconfig')
cellini_core_pkg.generate(
	gtkdot_lib,
	libraries : gtkdot_deps,
	name: meson.project_name(),
	description : 'Gtk Graphviz Library')

# generate typelib to be used in python
custom_target('gtkdot-typelib',
	command: [
		find_program('g-ir-compiler'),
			'--shared-library', 'libgtkdot-' + meson.project_version() + '.so',
			'--output', '@OUTPUT@',
			meson.current_build_dir() / 'Gtkdot-' + meson.project_version() + '.gir',
		],
	output:  'Gtkdot-' + meson.project_version() + '.typelib',
	depends: gtkdot_lib,
	install: true,
	install_dir: get_option('libdir') / 'girepository-1.0')