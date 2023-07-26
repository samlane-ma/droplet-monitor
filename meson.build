project('com.github.samlane-ma.droplet-monitor',
        ['vala', 'c'],
        version: '1.1',
        meson_version: '>=0.50.0',
        license: 'GPL3')

VAPI_DIR = join_paths(meson.current_source_dir(), 'vapi')

# Global path variable
prefix = get_option('prefix')
libdir = join_paths(prefix, get_option('libdir'))
datadir = join_paths(prefix, get_option('datadir'))
bindir = get_option('bindir')
if bindir == 'bin'
	bindir = join_paths(prefix, bindir)
endif

PIXMAPS_DIR = join_paths(datadir, 'pixmaps')
SCHEMA_DIR = join_paths(prefix, 'share', 'glib-2.0', 'schemas')

message('Installing applet...')

subdir('droplet-monitor-common')
subdir('droplet-monitor-applet')
subdir('droplet-monitor-widget')
