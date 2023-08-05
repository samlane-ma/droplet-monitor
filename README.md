# Budgie Droplet Monitor Applet and Widget

## Monitor Digital Ocean Droplets for the Budgie Panel

### This project is not associated in any way with DigitalOcean, LLC
### The provided applet and widget will allow you to see the status of, start, and stop droplets

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
* libsoup-3.0
* json-glib-1.0
* libsecret-1

i.e. for Debian based distros

To install (for Debian/Ubuntu):

    mkdir build
    cd build
    meson --prefix=/usr --libdir=/usr/lib
    ninja -v
    sudo ninja install

* To build just the applet, use -Dbuild-applet-only=true
* To build just the widget, use -Dbuild-widget-only=true
* for other distros omit libdir or specify the location of the distro library folder

This will:
* install the applet to the applet plugin folder
* install the widget to the widget plugin folder
* install the icons to the pixmap folder
* install and complile the schemas

