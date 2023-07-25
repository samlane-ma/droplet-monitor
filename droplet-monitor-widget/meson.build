WIDGET_ID = 'com.github.samlane-ma.widget.droplet-monitor'
WIDGET_INSTALL_DIR = join_paths(prefix, libdir, 'budgie-desktop', 'raven-plugins', WIDGET_ID)

DropletMonitorWidgetSources = ['dropletmonitor-widget.vala', 'dropletlist.vala', 'dropletmonitor-grid.vala', 'docean.vala']

DropletMonitorWidgetDependencies = [
    dependency('gtk+-3.0', version: '>=3.18'),
    dependency('libpeas-gtk-1.0'),
    dependency('budgie-1.0'),
    dependency('libsecret-1'),
    dependency('budgie-raven-plugin-1.0'),
    meson.get_compiler('c').find_library('m', required: false)
]
install_data('DropletMonitorWidget.plugin', install_dir: WIDGET_INSTALL_DIR)

SCHEMA_DIR = join_paths(prefix, 'share', 'glib-2.0', 'schemas')
install_data('com.github.samlane-ma.widget.droplet-monitor.gschema.xml',
    install_dir: SCHEMA_DIR,
)

shared_library(WIDGET_ID, DropletMonitorWidgetSources, dependencies: DropletMonitorWidgetDependencies, install: true, install_dir: WIDGET_INSTALL_DIR)

message('Installing applet...')