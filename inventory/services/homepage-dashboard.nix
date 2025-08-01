_: {
  instances = {
    "homepage-dashboard" = {
      module.name = "homepage-dashboard";
      module.input = "self";
      roles.server = {
        tags."homepage-server" = { };
        settings = {
          # Allow access from multiple hosts
          allowedHosts = "localhost:8082,127.0.0.1:8082,100.110.43.11:8082,britton-desktop:8082";

          # Dashboard configuration
          settings = {
            title = "Onix Services";
            theme = "dark";
            color = "slate";
            background = {
              image = "";
              blur = "sm";
              saturate = 50;
              brightness = 50;
              opacity = 50;
            };
          };

          # Services configuration
          services = [
            {
              "Infrastructure" = [
                {
                  "Vaultwarden" = {
                    icon = "bitwarden.png";
                    href = "http://100.110.43.11:8222";
                    description = "Password manager";
                    siteMonitor = "http://100.110.43.11:8222";
                  };
                }
                {
                  "Grafana" = {
                    icon = "grafana.png";
                    href = "http://100.110.43.11:3000";
                    description = "Metrics visualization";
                  };
                }
                {
                  "Prometheus" = {
                    icon = "prometheus.png";
                    href = "http://100.110.43.11:9090";
                    description = "Metrics collection";
                  };
                }
              ];
            }
          ];

          # Widgets configuration
          widgets = [
            {
              search = {
                provider = "duckduckgo";
                target = "_blank";
              };
            }
            {
              datetime = {
                text_size = "lg";
                format = {
                  dateStyle = "long";
                  timeStyle = "short";
                  hour12 = false;
                };
              };
            }
          ];

        };
      };
    };
  };
}
