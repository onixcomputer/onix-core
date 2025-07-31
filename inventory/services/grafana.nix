_: {
  instances = {
    # Grafana monitoring visualization
    "grafana" = {
      module.name = "grafana";
      module.input = "self";
      roles.server = {
        tags."desktop" = { };
        settings = {
          enablePrometheusIntegration = true;
          prometheusUrl = "http://localhost:9090";
          port = 3000;
          domain = "grafana.local";
          settings = {
            server = {
              http_addr = "0.0.0.0";
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
          };

          # Dashboard provisioning
          dashboards = [
            # Example: provision dashboards from a directory
            # {
            #   name = "System Dashboards";
            #   options.path = ./dashboards;
            #   options.foldersFromFilesStructure = true;
            # }
          ];

          # Database configuration (defaults to SQLite)
          database = {
            type = "sqlite3";
            path = "/var/lib/grafana/data/grafana.db";
          };

        };
      };
    };
  };
}
