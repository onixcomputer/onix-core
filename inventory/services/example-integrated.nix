# Example inventory showing integrated Traefik setup with multiple services
_: {
  instances = {
    # Traefik instance handling all services
    "main-proxy" = {
      module.name = "traefik";
      module.input = "self";
      roles.proxy = {
        tags."proxy" = { };
        tags."loadbalancer" = { };
        settings = {
          enableAutoTLS = true;
          acmeEmail = "admin@example.com";
          certificateResolver = "letsencrypt";

          enableDashboard = true;
          dashboardHost = "traefik.example.com";
          dashboardAuth = "basic";

          # Only external services need to be defined here
          # Clan services with traefik.enable = true auto-register
          services = [ ];

          defaultMiddlewares = [
            "security-headers"
            "compress"
          ];
        };
      };
    };

    # Grafana with automatic Traefik integration
    "monitoring-grafana" = {
      module.name = "grafana";
      module.input = "self";
      roles.server = {
        tags."monitoring" = { };
        settings = {
          # Grafana settings
          enablePrometheusIntegration = true;

          # This automatically configures Traefik routing
          traefik = {
            enable = true;
            host = "grafana.example.com";
            enableAuth = true; # Protect with basic auth
            authType = "basic";
            middlewares = [ "rate-limit" ];
          };

          settings = {
            server = {
              http_addr = "0.0.0.0";
              http_port = 3000;
              domain = "grafana.example.com";
              root_url = "https://%(domain)s/";
            };
          };
        };
      };
    };

    # Vaultwarden with automatic Traefik integration
    "password-vault" = {
      module.name = "vaultwarden";
      module.input = "self";
      roles.server = {
        tags."vaultwarden-server" = { };
        settings = {
          DOMAIN = "https://vault.example.com";
          SIGNUPS_ALLOWED = false;

          # This automatically configures Traefik routing
          traefik = {
            enable = true;
            host = "vault.example.com";
            enableAuth = false; # Vaultwarden has its own auth
            middlewares = [ ];
          };
        };
      };
    };

    # Example with Tailscale setup
    "internal-proxy" = {
      module.name = "traefik";
      module.input = "self";
      roles.proxy = {
        tags."tailscale-proxy" = { };
        settings = {
          enableAutoTLS = true;
          certificateResolver = "tailscale"; # Use Tailscale certs

          enableDashboard = true;
          dashboardHost = "traefik.corp.ts.net";
          dashboardAuth = "none"; # Tailscale network provides security

          services = [ ];
          defaultMiddlewares = [ "security-headers" ];
        };
      };
    };

    # Internal Grafana with Tailscale auth
    "internal-grafana" = {
      module.name = "grafana";
      module.input = "self";
      roles.server = {
        tags."internal-monitoring" = { };
        settings = {
          enablePrometheusIntegration = true;

          # Tailscale auth through Traefik
          traefik = {
            enable = true;
            host = "grafana.corp.ts.net";
            enableAuth = true;
            authType = "tailscale";
            tailscaleDomain = "corp.ts.net";
            middlewares = [ ];
          };

          settings = {
            server = {
              http_addr = "0.0.0.0";
              http_port = 3000;
            };
          };
        };
      };
    };
  };
}
