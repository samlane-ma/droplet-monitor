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

build_without_widget = get_option('build-without-widget')
build_without_applet = get_option('build-without-applet')

if build_without_widget == true and build_without_applet == true
        error('Option build-without-applet cannot be used with build-without-widget')
endif

subdir('droplet-monitor-common')

if build_without_widget == false
        subdir('droplet-monitor-widget')
endif

if build_without_applet == false
        subdir('droplet-monitor-applet')
endif

message('Installing applet...')
meson.add_install_script('meson_post_install')
