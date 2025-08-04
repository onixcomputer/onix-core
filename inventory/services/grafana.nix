{ inputs }:
{
  instances = {
    # Grafana monitoring visualization
    "grafana" = {
      module.name = "grafana";
      module.input = "self";
      roles.server = {
        tags."monitoring" = { };
        settings = {
          enablePrometheusIntegration = true;
          prometheusUrl = "http://localhost:9090";

          # Add Loki datasource
          additionalDatasources = [
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://localhost:3100";
              jsonData = {
                maxLines = 1000;
              };
            }
          ];

          # Traefik integration - will auto-configure if Traefik is available
          traefik = {
            enable = true;
            host = "grafana.bison-tailor.ts.net"; # Tailscale domain
            # NOTE: Ensure DNS resolves this hostname to your machine's IP
            # Options: Tailscale DNS aliases, /etc/hosts, or use machine's actual Tailscale name
            enableAuth = true; # Enable Tailscale authentication
            authType = "tailscale"; # Use Tailscale auth
            tailscaleDomain = "bison-tailor.ts.net"; # Your tailnet domain
            middlewares = [ ]; # Additional middlewares beyond defaults
          };

          settings = {
            server = {
              http_addr = "0.0.0.0";
              http_port = 3000;
              domain = "grafana.bison-tailor.ts.net";
              root_url = "https://%(domain)s/";
              enable_gzip = true;
            };

            security = {
              admin_user = "admin";
            };

            analytics = {
              reporting_enabled = false;
              check_for_updates = false;
            };

            users = {
              allow_sign_up = false;
              default_theme = "dark";
            };

            feature_toggles = {
              enable = "publicDashboards";
            };

            database = {
              type = "sqlite3";
              path = "/var/lib/grafana/data/grafana.db";
            };
          };

          # Dashboard provisioning from external flake
          dashboards = [
            {
              name = "System Dashboards";
              type = "file";
              options.path = inputs.grafana-dashboards;
              options.foldersFromFilesStructure = false;
            }
          ];
        };
      };
    };
  };
}
