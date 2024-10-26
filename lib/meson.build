
gtkdot_deps = [

  # We make use of some Gsk components that are
  # available only from version 4.14 and above.
  dependency('gtk4', version: '>=  4.14'),

  dependency('json-glib-1.0'),
  # Required for Math operations
  # meson.get_compiler('c').find_library('m', required: false),

]

gtkdot_conf_data = configuration_data()
gtkdot_conf_data.set('VERSION',  meson.project_version() )
gtkdot_config = configure_file(
	input: 'config.vala.meson',
	output: 'config.vala',
	configuration: gtkdot_conf_data)

gtkdot_sources = [
	'graph.vala',
	'layout.vala',
	'widgets.vala',
]

gtkdot_lib_inc = include_directories('.')

# build shared library
gtkdot_lib = shared_library('gtkdot-' + meson.project_version(),
	gtkdot_sources,
	vala_header: 'gtkdot.h',
	vala_vapi:   'gtkdot-' + meson.project_version() + '.vapi',
	vala_gir:    'Gtkdot-' + meson.project_version() + '.gir',
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
