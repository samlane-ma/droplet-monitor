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
    public string[] ipv4;
    public string[] ipv6;
    public string id;
}

void power_droplet(string token, DODroplet drop, int mode) throws Error {
    var session = new Soup.Session();
    var message = new Soup.Message ("POST", @"https://api.digitalocean.com/v2/droplets/$(drop.id)/actions");
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
        string[] allv4 = {};
        string[] allv6 = {};
 
        var drop = droplet.get_object ();
        var networks = drop.get_member("networks").get_object();
        var ip4list = networks.get_array_member("v4");
        var ip6list = networks.get_array_member("v6");
        var regioninfo = drop.get_member("region").get_object();
      
        foreach (var ip in ip4list.get_elements()) {
            if (ip.get_object().get_string_member("type") == "public") {
                allv4 += ip.get_object().get_string_member("ip_address");
            }
        };

        foreach (var ip in ip6list.get_elements()) {
            if (ip.get_object().get_string_member("type") == "public") {
                allv6 += ip.get_object().get_string_member("ip_address");
            }
        };
       
        if (allv6.length == 0 ) {
            allv6 = {"none"};
        }

        if (allv4.length == 0) {
            allv4 = {"none"};
        }

        DODroplet found_droplet = DODroplet() {
            name = drop.get_string_member ("name"),
            id = drop.get_int_member("id").to_string(),
            ipv4 = allv4,
            ipv6 = allv6,
            status = drop.get_string_member("status"),
            location = regioninfo.get_string_member("name")
        };
        droplet_list += found_droplet;
    }
    return (droplet_list);
}

}