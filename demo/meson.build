
gtkdot_gresources = gnome.compile_resources('gtkdot-resources',
  'gtkdot.gresource.xml',
  c_name: 'gtkdot'
)

# executable('gtkdot',
executable('gtkdot-graph-demo',
  [ 'graph.vala' ] + gtkdot_gresources,
  dependencies: gtkdot_deps,
  link_with: gtkdot_lib,
  include_directories: gtkdot_lib_inc,
  install: true,
)

executable('gtkdot',
#executable('gtkdot-dot-demo',
  [ 'dot.vala' ] + gtkdot_gresources,
  dependencies: gtkdot_deps,
  link_with: gtkdot_lib,
  include_directories: gtkdot_lib_inc,
  install: true,
)