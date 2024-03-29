/*
 * This file is part of the Budgie Droplet Monitor applet
 *
 * Copyright Samuel Lane
 * Website=https://github.com/samlane-ma/droplet-monitor
 *
 * This program is free software: you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version
 * 3 of the License, or (at your option) any later version.
 */

namespace DropletMonitorWidget {

const int OFF = 0;
const int ON = 1;
const int REBOOT = 2;

struct DODroplet {
    public string name;
    public string location;
    public string status;
    public string public_ipv4;
    public string public_ipv6;
    public string private_ipv4;
    //public string private_ipv6;
    public string floating_ip;
    public string id;
    public string image_name;
    public string image_distribution;
    public string image_description;
    public string image_created;
    public string size_vcpus;
    public string size_storage;
    public string size_memory;
    //public string size_slug;
    public string size_price_monthly;
}

}
