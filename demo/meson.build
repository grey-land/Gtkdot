
gtkdot_gresources = gnome.compile_resources('gtkdot-resources',
  'gtkdot.gresource.xml',
  c_name: 'gtkdot'
)

executable('gtkdot-light-demo',
  [ 'light.vala' ] + gtkdot_gresources,
  dependencies: gtkdot_deps,
  link_with: gtkdot_lib,
  include_directories: gtkdot_lib_inc,
  install: true,
)

executable('gtkdot-simple-demo',
  [ 'simple.vala' ] + gtkdot_gresources,
  dependencies: gtkdot_deps,
  link_with: gtkdot_lib,
  include_directories: gtkdot_lib_inc,
  install: true,
)