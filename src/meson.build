
install_data('DropletMonitor.plugin', install_dir: LIB_INSTALL_DIR)

configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', meson.project_name())
configurationData.set('PACKAGE_BINDIR', bindir)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

 service_conf_data = configuration_data()
 service_conf_data.set('BINDIR', bindir)
 configure_file(input : 'com.github.samlane_ma.droplet_monitor.service.in',
               output : 'com.github.samlane_ma.droplet_monitor.service',
               configuration : service_conf_data,
               install: true,
               install_dir: join_paths(datadir, 'dbus-1', 'services'))


DropletMonitorSources = [
    'dropletmonitor-applet.vala',
    'dropletlist.vala',
    'dropletmonitor-popover.vala',
    'docean.vala',
    'curl-easy.vala',
]

DropletMonitorDependencies = [
    dependency('gtk+-3.0'),
    dependency('budgie-1.0'),
    dependency('gdk-3.0'),
    dependency('libpeas-gtk-1.0'),
    dependency('libsecret-1'),
    dependency('json-glib-1.0'),
    dependency('libcurl'),
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

ServerSources = [
    'server-dm.vala'
]

ServerDependencies = [
    dependency('json-glib-1.0'),
    dependency('libsoup-3.0'),
]

shared_library('dropletmonitor', DropletMonitorSources, dependencies: DropletMonitorDependencies, c_args: DropletMonitorCArgs, vala_args: DropletMonitorValaArgs, install: true, install_dir: LIB_INSTALL_DIR)
executable('server-dm', ServerSources, dependencies: ServerDependencies, install: true, install_dir: bindir)
