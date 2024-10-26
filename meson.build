project('gtkdot', ['c', 'vala'],
          version: '0.1.0',
    meson_version: '>= 1.0.0',
  default_options: [ 'warning_level=2', 'werror=false', ],
)

i18n = import('i18n')
gnome = import('gnome')
valac = meson.get_compiler('vala')

add_project_arguments('-DGETTEXT_PACKAGE="' + meson.project_name () + '"', language: 'c')

subdir('data')
subdir('lib')
subdir('demo')
subdir('po')

gnome.post_install(
     glib_compile_schemas: true,
    gtk_update_icon_cache: true,
  update_desktop_database: true,
)