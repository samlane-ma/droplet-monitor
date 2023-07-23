 service_conf_data = configuration_data()
 service_conf_data.set('BINDIR', bindir)
 configure_file(input : 'com.github.samlane_ma.droplet_monitor.service.in',
               output : 'com.github.samlane_ma.droplet_monitor.service',
               configuration : service_conf_data,
               install: true,
               install_dir: join_paths(datadir, 'dbus-1', 'services'))

ServerSources = [
    'server-dm.vala'
]

ServerDependencies = [
    dependency('json-glib-1.0'),
    dependency('libsoup-3.0'),
]

executable('server-dm', ServerSources, dependencies: ServerDependencies, install: true, install_dir: bindir)
