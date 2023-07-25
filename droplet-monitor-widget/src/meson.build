DropletMonitorWidgetSources = ['dropletmonitor-widget.vala', 'dropletlist.vala', 'dropletmonitor-grid.vala', 'docean.vala']

DropletMonitorWidgetDependencies = [
    dependency('gtk+-3.0', version: '>=3.18'),
    dependency('libpeas-gtk-1.0'),
    dependency('budgie-1.0'),
    dependency('libsecret-1'),
    dependency('budgie-raven-plugin-1.0'),
    meson.get_compiler('c').find_library('m', required: false)
]

shared_library(WIDGET_ID, DropletMonitorWidgetSources, dependencies: DropletMonitorWidgetDependencies, install: true, install_dir: WIDGET_INSTALL_DIR)
