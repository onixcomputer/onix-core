_: {
  instances = {
    # Grafana monitoring visualization
    "grafana" = {
      module.name = "grafana";
      module.input = "self";
      roles.server = {
        tags."monitoring" = { };
        settings = {
          enablePrometheusIntegration = true;
          # prometheusUrl and Loki datasource are auto-discovered from exports.
          # Override prometheusUrl here only if the Prometheus server is on a
          # different host than Grafana.

          settings = {
            server = {
              http_addr = "0.0.0.0";
              http_port = 3000;
              domain = "grafana.local";
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

          # TODO: Add dashboard provisioning when grafana-dashboards input is available
          # dashboards = [
          #   {
          #     name = "System Dashboards";
          #     type = "file";
          #     options.path = inputs.grafana-dashboards;
          #     options.foldersFromFilesStructure = false;
          #   }
          # ];
        };
      };
    };
  };
}
