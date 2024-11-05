project('gtkdot', ['c', 'vala'],
	version: '0.1.0',
	meson_version: '>= 1.0.0',
	default_options: [
		'warning_level=2',
		'werror=false',
		'pkgconfig.relocatable=true',
	],
)

add_project_arguments(['--vapidir',  meson.current_source_dir() / 'vapi' ], language: 'vala')

pkg = import('pkgconfig')
subdir('lib')

gnome = import('gnome')
subdir('demo')
