_: {
  instances = {
    "tailscale-traefik-fw" = {
      module.name = "tailscale-traefik";
      module.input = "self";
      roles.server = {
        tags."traefik-blrdev" = { }; # Any machine with this tag will run this instance
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

            # Wiki.js - private access (Tailscale only)
            wiki = {
              port = 3000;
              subdomain = "wiki";
              public = false; # This service is only accessible via Tailscale
            };

            # SeaweedFS Filer - private access (Tailscale only)
            seaweed = {
              port = 8890;
              subdomain = "seaweed";
              public = false; # This service is only accessible via Tailscale
            };

            # SeaweedFS Master - private access (Tailscale only)
            seaweed-master = {
              port = 9333;
              subdomain = "seaweed-master";
              public = false; # This service is only accessible via Tailscale
            };

            # SeaweedFS S3 API - private access (Tailscale only)
            seaweed-s3 = {
              port = 8333;
              subdomain = "s3";
              public = false; # This service is only accessible via Tailscale
            };
            loki = {
              port = 3100;
              subdomain = "loki";
              public = false; # This service is only accessible via Tailscale
            };
            grafana = {
              subdomain = "grafana";
              public = false; # This service is only accessible via Tailscale
            };
            prometheus = {
              subdomain = "prometheus";
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

          # Disable DNS propagation check to fix ACME challenges
          dnsPropagationCheck = false;

          # Increase propagation delay if re-enabling propagation check
          # dnsPropagationDelay = 300; # 5 minutes instead of default 2 minutes
        };
      };
    };
    "tailscale-traefik-desktop" = {
      module.name = "tailscale-traefik";
      module.input = "self";
      roles.server = {
        tags."traefik-desktop" = { }; # Any machine with this tag will run this instance
        settings = {
          domain = "onix.computer";
          email = "admin@onix.computer";

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

            # Wiki.js - private access (Tailscale only)
            wiki = {
              port = 3000;
              subdomain = "wiki";
              public = false; # This service is only accessible via Tailscale
            };

            # SeaweedFS Filer - private access (Tailscale only)
            seaweed = {
              port = 8890;
              subdomain = "seaweed";
              public = false; # This service is only accessible via Tailscale
            };

            # SeaweedFS Master - private access (Tailscale only)
            seaweed-master = {
              port = 9333;
              subdomain = "seaweed-master";
              public = false; # This service is only accessible via Tailscale
            };

            # SeaweedFS S3 API - private access (Tailscale only)
            seaweed-s3 = {
              port = 8333;
              subdomain = "s3";
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

          # Disable DNS propagation check to fix ACME challenges
          dnsPropagationCheck = false;

          # Increase propagation delay if re-enabling propagation check
          # dnsPropagationDelay = 300; # 5 minutes instead of default 2 minutes
        };
      };
    };
  };
}
