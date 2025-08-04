_: {
  instances = {
    # Instance for britton-desktop (running the actual services)
    "tailscale-traefik-onix" = {
      module.name = "tailscale-traefik";
      module.input = "self";
      roles.server = {
        machines."britton-desktop" = { };
        settings = {
          domain = "blr.dev";
          email = "admin@blr.dev";

          # Services to expose (running locally on britton-desktop)
          services = {
            grafana = {
              port = 3000;
            };
            vaultwarden = {
              port = 8222;
            };
          };

          # Enable Tailscale features
          tailscaleSSH = true;
          tailscaleExitNode = false;

          # Enable Traefik dashboard
          traefikDashboard = true;

          # Security headers enabled by default
          securityHeaders = true;
        };
      };
    };

    # Instance for britton-fw (just homepage)
    "tailscale-traefik-fw" = {
      module.name = "tailscale-traefik";
      module.input = "self";
      roles.server = {
        tags."traefik-homepage" = { }; # Any machine with this tag will run this instance
        settings = {
          domain = "blr.dev";
          email = "admin@blr.dev";

          # Test public mode - REMEMBER TO SET UP PORT FORWARDING!
          publicMode = true;

          # Services to expose
          services = {
            # Homepage - auto-detected port
            homepage = {
              subdomain = "home";
            };

            # Static test server
            test = {
              port = 8888;
              subdomain = "test";
            };
          };

          # Enable Tailscale features
          tailscaleSSH = true;
          tailscaleExitNode = false;

          # Enable Traefik dashboard
          traefikDashboard = false; # Avoid conflict with britton-desktop

          # Security headers enabled by default
          securityHeaders = true;
        };
      };
    };
  };
}
