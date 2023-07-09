
install_data('DropletManager.plugin', install_dir: LIB_INSTALL_DIR)

AppletNameSources = [
'dropletmanager-applet.vala',
'dropletlist.vala',
'dropletmanager-popover.vala',
'docean.vala',
'curl-easy.vala',
]

AppletNameDependencies = [
dependency('gtk+-3.0', version: '>=3.18'), 
dependency('budgie-1.0', version: '>=2'),
dependency('gdk-3.0'),
dependency('libpeas-gtk-1.0'),
dependency('libsecret-1'),
dependency('json-glib-1.0'),
dependency('libcurl'),
meson.get_compiler('vala').find_library('posix'),
meson.get_compiler('c').find_library('m', required: false)
]

AppletNameValaArgs = [
'--target-glib=2.38',
'--vapidir=' + VAPI_DIR,
]

shared_library('dropletmanager', AppletNameSources, dependencies: AppletNameDependencies, vala_args: AppletNameValaArgs, install: true, install_dir: LIB_INSTALL_DIR)
