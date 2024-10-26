gtkdot_sources = [
  'window.vala',
  'application.vala',
]

gtkdot_sources += gnome.compile_resources('gtkdot-resources',
  'gtkdot.gresource.xml',
  c_name: 'gtkdot'
)

executable('gtkdot', gtkdot_sources,
  dependencies: gtkdot_deps,
  link_with: gtkdot_lib,
  install: true,
)