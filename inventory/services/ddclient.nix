_: {
  instances = {
    "ddclient" = {
      module.name = "ddclient";
      module.input = "self";
      roles.server = {
        tags."ddclient-server" = { };
        settings = {
          # Clan-specific convenience options
          domains = [
            "example.com"
            "subdomain.example.com"
          ];
          dnsProvider = "cloudflare"; # Options: cloudflare, namecheap, dyndns, noip, freedns, custom
          updateInterval = "10min"; # How often to check and update DNS

          # Cloudflare-specific settings (required when dnsProvider = "cloudflare")
          cloudflareZone = "1234567890abcdef1234567890abcdef"; # Your Cloudflare Zone ID
          # Note: You'll be prompted for your Cloudflare API Token on first deployment
          # The token needs Zone:DNS:Edit permissions for your domain

          # For Cloudflare, username is typically your email
          username = "myuser@example.com";

          # Optional: Override auto-detection methods
          # use = "web"; # Method to determine IP: web, if, cmd
          # usev4 = "webv4"; # IPv4 detection method
          # usev6 = "webv6"; # IPv6 detection method

          # For non-Cloudflare providers, you might need:
          # password = "your-password"; # Not needed for Cloudflare (uses API token instead)

          # Optional: Custom configuration file (overrides all other settings)
          # configFile = "/path/to/custom/ddclient.conf";

          # Optional: Logging options
          # verbose = true;
          # quiet = false;
        };
      };
    };
  };
}
