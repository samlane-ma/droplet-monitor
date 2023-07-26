WIDGET_NAME = meson.project_name() + '.widget'
WIDGET_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'raven-plugins', WIDGET_NAME)

subdir('src')
subdir('data')

meson.add_install_script('meson_post_install')
