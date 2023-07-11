project('com.github.samlane-ma.applet.droplet-monitor',
        ['vala', 'c'],
        version: '1.1',
        meson_version: '>=0.40.0',
        license: 'GPL3')

VAPI_DIR = join_paths(meson.current_source_dir(), 'vapi')

# Global path variable
prefix = get_option('prefix')
libdir = join_paths(prefix, get_option('libdir'))
datadir = join_paths(prefix, get_option('datadir'))

PIXMAPS_DIR = join_paths(datadir, 'pixmaps')

LIB_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'plugins', meson.project_name())

message('Installing applet...')

subdir('src')
subdir('icons')
