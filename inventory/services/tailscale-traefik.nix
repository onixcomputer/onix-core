_: {
  instances = {
    "tailscale-traefik-fw" = {
      module.name = "tailscale-traefik";
      module.input = "self";
      roles.server = {
        tags."traefik-homepage" = { }; # Any machine with this tag will run this instance
        settings = {
          domain = "blr.dev";
          email = "admin@blr.dev";

          # Services to expose
          services = {
            # Homepage - private access
            homepage = {
              subdomain = "home";
              public = false;
            };

            # Static test server - public access
            test = {
              port = 8888;
              subdomain = "test";
              public = true; # This service is accessible from the internet
            };

            # Demo static server - private access (Tailscale only)
            demo = {
              port = 8889;
              subdomain = "demo";
              public = false; # This service is only accessible via Tailscale
            };

            # Vault dev instance - private access (Tailscale only)
            vault = {
              port = 8200;
              subdomain = "vault1";
              public = false; # This service is only accessible via Tailscale
            };

          };

          # Enable Tailscale features
          tailscaleSSH = true;
          tailscaleExitNode = false;

          # Enable Traefik dashboard (private by default)
          traefikDashboard = true;

          # Security headers enabled by default
          securityHeaders = true;
        };
      };
    };
  };
}
