using Soup;
using Json;

namespace DOcean {

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
    public string private_ipv6;
    public string floating_ip;
    public string id;
    public string image_name;
    public string image_distribution;
    public string image_description;
    public string image_created;
    public string size_vcpus;
    public string size_storage;
    public string size_memory;
    public string size_slug;
    public string size_price_monthly;
}

void power_droplet(string token, string droplet_id, int mode) throws Error {
    var session = new Soup.Session();
    session.timeout = 5;
    var message = new Soup.Message ("POST", @"https://api.digitalocean.com/v2/droplets/$droplet_id/actions");
    string mparams = "";
    if (mode == ON) {
        mparams = "{\"type\":\"power_on\"}";
    } else if (mode == OFF) {
        mparams = "{\"type\":\"shutdown\"}";
    } else if (mode == REBOOT) {
        mparams = "{\"type\":\"reboot\"}";
    }
    Soup.MemoryUse buffer = Soup.MemoryUse.STATIC; 
    message.set_request("application/json", buffer, mparams.data);
    message.request_headers.append("Content-Type","application/json");
    message.request_headers.append ("Authorization", @"Bearer $token");
    session.send_message(message);
    if (message.response_body.data == null) {
        throw new Error(Quark.from_string ("DROPLETS"), 30, "Cannot Reach Server");
    } else if ("could not be found." in ((string)message.response_body.data)) {
        throw new Error(Quark.from_string ("DROPLETS"), 50, "Could not perform requested action");
    } else if ("Unable to authenticate you" in ((string)message.response_body.data)) {
        throw new Error(Quark.from_string ("DROPLETS"), 20, "Unable to authenticate you");
    }
}

DODroplet[] get_droplets (string token) throws Error {
   
    DODroplet[]droplet_list = {};

    var session = new Soup.Session();
    session.timeout = 5;
    var message = new Soup.Message ("GET", "https://api.digitalocean.com/v2/droplets");
    message.request_headers.append ("Authorization", @"Bearer $token");
    session.send_message(message);
   
    if (message.response_body.data == null) { 
        throw new Error(Quark.from_string ("DROPLETS"), 30, "Cannot Reach Server");
    }
   
    if ((string) message.response_body.data == "{\"id\": \"Unauthorized\", \"message\": \"Unable to authenticate you\" }") {
        throw new Error(Quark.from_string ("DROPLETS"), 20, "Unable to authenticate you");
    }

    var parser = new Json.Parser ();
    parser.load_from_data ((string) message.response_body.flatten ().data, -1);
    var root_object = parser.get_root ().get_object ();
    var response = root_object.get_array_member ("droplets");
    if (response == null) {
        throw new Error(Quark.from_string ("DROPLETS"), 40, "Bad Data");
    }
    
    foreach (var droplet in response.get_elements ()) {
        string ipv4 = "N/A";
        string ipv6 = "N/A";
        string priv_ipv4 = "N/A";
        string priv_ipv6 = "N/A";
        string drop_floating_ip = "N/A";
        string[] all_ips = {};

        var drop = droplet.get_object ();

        var networks = drop.get_member("networks").get_object();
        var ip4list = networks.get_array_member("v4");
        var ip6list = networks.get_array_member("v6");

        var regioninfo = drop.get_member("region").get_object();
        var imageinfo = drop.get_member("image").get_object();
        var sizeinfo = drop.get_member("size").get_object();

        foreach (var ip in ip4list.get_elements()) {
            if (ip.get_object().get_string_member("type") == "public") {
                string ipaddr = ip.get_object().get_string_member("ip_address");
                if (ipaddr in all_ips) {
                    drop_floating_ip = ipaddr;
                } else {
                    all_ips += ipaddr;
                }
            } else {
                priv_ipv4 = ip.get_object().get_string_member("ip_address");
            }
        };
        foreach (string ip in all_ips) {
            if (ip != drop_floating_ip) {
                ipv4 = ip;
            }
        }

        foreach (var ip in ip6list.get_elements()) {
            if (ip.get_object().get_string_member("type") == "public") {
                ipv6 = ip.get_object().get_string_member("ip_address");
            } else {
                priv_ipv6 = ip.get_object().get_string_member("ip_address");
            }
        };

        DODroplet found_droplet = DODroplet() {
            name = drop.get_string_member ("name"),
            id = drop.get_int_member("id").to_string(),
            public_ipv4 = ipv4,
            public_ipv6 = ipv6,
            private_ipv4 = priv_ipv4,
            private_ipv6 = priv_ipv6,
            floating_ip = drop_floating_ip,
            status = drop.get_string_member("status"),
            location = regioninfo.get_string_member("name"),
            image_name = imageinfo.get_string_member("name"),
            image_created = imageinfo.get_string_member("created_at"),
            image_distribution = imageinfo.get_string_member("distribution"),
            image_description = imageinfo.get_string_member("description"),
            size_vcpus = sizeinfo.get_int_member("vcpus").to_string(),
            size_storage = sizeinfo.get_int_member("disk").to_string(),
            size_memory = sizeinfo.get_int_member("memory").to_string(),
            size_slug = sizeinfo.get_string_member("slug"),
            size_price_monthly = sizeinfo.get_int_member("price_monthly").to_string()
        };

        droplet_list += found_droplet;
    }
    return droplet_list;
}

}