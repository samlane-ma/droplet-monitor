

configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', meson.project_name())
configurationData.set('PACKAGE_BINDIR', bindir)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

DropletMonitorSources = [
    'dropletmonitor-applet.vala',
    'dropletlist.vala',
    'dropletmonitor-popover.vala',
    'docean.vala',
]

DropletMonitorDependencies = [
    dependency('gtk+-3.0'),
    dependency('budgie-1.0'),
    dependency('gdk-3.0'),
    dependency('libpeas-gtk-1.0'),
    dependency('libsecret-1'),
    dependency('json-glib-1.0'),
    meson.get_compiler('vala').find_library('posix'),
    meson.get_compiler('c').find_library('m', required: false)
]

DropletMonitorValaArgs = [
    '--pkg=config',
    '--target-glib=2.38',
    '--vapidir=' + VAPI_DIR,
]

DropletMonitorCArgs = [
    '-include',
    'config.h'
]

shared_library(APPLET_NAME, DropletMonitorSources, dependencies: DropletMonitorDependencies, c_args: DropletMonitorCArgs, vala_args: DropletMonitorValaArgs, install: true, install_dir: APPLET_INSTALL_DIR)
