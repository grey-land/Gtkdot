
gtkdot_deps = [

	# We make use of some Gsk components that are
	# available only from Gtk version 4.14 and above.
	dependency('gtk4', version: '>=  4.14'),

	# Graphviz ( currently use 12.1.2 ) should work for > 2.3 but not tested.
	# Keep in mind that we use our custom vapi file ( ../vapi/libgvc.vapi )
	# configured with `--vapidir` through `add_project_arguments`.
	dependency('libgvc', version: '>= 2.3' ),

]

gtkdot_sources = [
	'utils.vala',
	'interfaces.vala',
	'light.vala',
	'simple.vala',
	'simple_member.vala',
]

gtkdot_lib_inc = include_directories('.')

# Generate config.vala file
gtkdot_conf_data = configuration_data()
gtkdot_conf_data.set('VERSION',  meson.project_version() )
gtkdot_config = configure_file(
	input: 'config.vala.meson',
	output: 'config.vala',
	configuration: gtkdot_conf_data)
# Add config.vala to sources
gtkdot_sources += gtkdot_config

# Build shared library
gtkdot_lib = shared_library('gtkdot-' + meson.project_version(),
	gtkdot_sources,
	vala_header: 'gtkdot.h',
	vala_vapi: 'gtkdot-' + meson.project_version() + '.vapi',
	vala_gir: 'Gtkdot-' + meson.project_version() + '.gir',
	dependencies: gtkdot_deps,
	include_directories: gtkdot_lib_inc,
	install: true,
	install_dir: [true, true, true, true],

)

# Generate pkg-config for shared library
pkg.generate(
	gtkdot_lib,
	libraries : gtkdot_deps,
	name: meson.project_name(),
	description : 'Gtk Graphviz Itergration library')

# Add some testing
test('gtkdot-test',
	executable('gtkdot-test',
		sources: files(
			'test_vapi.vala',
			'test.vala',
		) + gtkdot_sources,
		dependencies : gtkdot_deps),
	env: [
		'G_TEST_SRCDIR=@0@'.format(meson.current_source_dir()),
		'G_TEST_BUILDDIR=@0@'.format(meson.current_build_dir()),
	]
)