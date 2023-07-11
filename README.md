# Budgie Droplet Monitor Applet

## Monitor Digital Ocean Droplets for the Budgie Panel

### This applet is not associated in any way with DigitalOcean, LLC
### This applet will allow you to see the status of, start, and stop droplets

![Image 1](images/img1.png)

![Image 2](images/img2.png)

The applet requires a token provided by Digital Ocean.
The token will be stored in the gnome keyring, so if the keyring is not unlocked (i.e. if using auto-login) the applet will not work.
A token with "Write" scope is needed to start/stop/reboot droplets.

[How to obtain your Digital Ocean Token](https://docs.digitalocean.com/reference/api/create-personal-access-token/)

Dependencies

* gtk+-3.0
* budgie-1.0
* gdk-3.0
* libpeas-gtk-1.0
* libcurl
* json-glib-1.0
* libsecret-1

i.e. for Debian based distros

To install (for Debian/Ubuntu):

    mkdir build
    cd build
    meson --prefix=/usr --libdir=/usr/lib
    ninja -v
    sudo ninja install

* for other distros omit libdir or specify the location of the distro library folder

This will:
* install plugin files to the Budgie Desktop plugins folder

This version of Droplet Monitor drops libsoup2.4 and uses libcurl instead, to avoid
any conflicts during a transition to libsoup3 (as it is impossible to have an applet
that uses libsoup2.4 and an applet that uses libsoup3 on the panel at the same time).

It makes use of parts of the curl-vala project by Richard Wiedenhöft.
https://github.com/Richard-W/curl-vala
