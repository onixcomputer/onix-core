{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    bool
    str
    nullOr
    listOf
    attrsOf
    anything
    ;

  # Import Traefik integration helpers
  traefikLib = import ../traefik/lib.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest.name = "grafana";

  # Define available roles
  roles = {
    # Grafana server role
    server = {
      interface = {
        # Allow freeform configuration that maps directly to services.grafana
        freeformType = attrsOf anything;

        options = {
          # Clan-specific options
          enablePrometheusIntegration = mkOption {
            type = bool;
            default = true;
            description = "Whether to automatically configure Prometheus as a datasource";
          };

          prometheusUrl = mkOption {
            type = nullOr str;
            default = null;
            description = "URL of the Prometheus server (defaults to http://localhost:9090)";
          };

          # Additional datasources beyond Prometheus
          additionalDatasources = mkOption {
            type = listOf anything;
            default = [ ];
            description = "Additional datasources to configure";
          };

          # Additional dashboards
          dashboards = mkOption {
            type = listOf anything;
            default = [ ];
            description = "Dashboard configurations";
          };

          # Notification channels
          notifiers = mkOption {
            type = listOf anything;
            default = [ ];
            description = "Notification channel configurations";
          };

          # Traefik integration using shared options
          traefik = traefikLib.mkTraefikOptions;
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              lib,
              ...
            }:
            let
              # Get the extended settings
              settings = extendSettings { };

              # Extract clan-specific options
              enablePrometheusIntegration = settings.enablePrometheusIntegration or true;
              prometheusUrl = settings.prometheusUrl or "http://localhost:9090";
              additionalDatasources = settings.additionalDatasources or [ ];
              dashboards = settings.dashboards or [ ];
              notifiers = settings.notifiers or [ ];
              traefikConfig = settings.traefik or { };

              # Remove clan-specific options before passing to services.grafana
              grafanaConfig = builtins.removeAttrs settings [
                "enablePrometheusIntegration"
                "prometheusUrl"
                "additionalDatasources"
                "dashboards"
                "notifiers"
                "traefik"
              ];

              # Use clan vars for secrets
              adminPasswordFile = config.clan.core.vars.generators.grafana.files.admin_password.path;
              secretKeyFile = config.clan.core.vars.generators.grafana.files.secret_key.path;

              # Prometheus datasource configuration
              prometheusDatasource = {
                name = "Prometheus";
                type = "prometheus";
                access = "proxy";
                url = prometheusUrl;
                isDefault = true;
                jsonData = {
                  timeInterval = "5s";
                };
              };

              # Combine all datasources
              allDatasources =
                if enablePrometheusIntegration then
                  [ prometheusDatasource ] ++ additionalDatasources
                else
                  additionalDatasources;

            in
            {
              # Enable Grafana with the freeform configuration
              services.grafana = lib.mkMerge [
                {
                  enable = true;
                  settings = {
                    security = {
                      admin_password = "$__file{${adminPasswordFile}}";
                      secret_key = "$__file{${secretKeyFile}}";
                    };
                  };
                }
                grafanaConfig
                {
                  # Configure datasources if any
                  provision =
                    lib.mkIf
                      (allDatasources != [ ] || dashboards != [ ] || notifiers != [ ] || enablePrometheusIntegration)
                      {
                        enable = true;

                        datasources.settings = lib.mkIf (allDatasources != [ ]) {
                          apiVersion = 1;
                          datasources = allDatasources;
                          deleteDatasources = [ ];
                        };

                        dashboards.settings =
                          let
                            userDashboards =
                              if dashboards != [ ] then
                                {
                                  apiVersion = 1;
                                  providers = dashboards;
                                }
                              else
                                null;
                            defaultDashboards = null;
                          in
                          if userDashboards != null && defaultDashboards != null then
                            userDashboards // { providers = userDashboards.providers ++ defaultDashboards.providers; }
                          else if userDashboards != null then
                            userDashboards
                          else if defaultDashboards != null then
                            defaultDashboards
                          else
                            null;

                        notifiers = lib.mkIf (notifiers != [ ]) notifiers;
                      };
                }
              ];

              # Use the reusable Traefik integration helper
              services.traefik = traefikLib.mkTraefikIntegration {
                serviceName = "grafana";
                servicePort = config.services.grafana.settings.server.http_port;
                inherit traefikConfig config;
              };

              # Open firewall for Grafana
              networking.firewall.allowedTCPPorts = [
                config.services.grafana.settings.server.http_port
              ];

              # Ensure grafana user can read certificates if HTTPS is enabled
              users.users.grafana =
                lib.mkIf (config.services.grafana.settings.server.protocol or "http" == "https")
                  {
                    extraGroups = [ "nginx" ]; # Adjust based on your cert setup
                  };
            };
        };
    };
  };

  # Common configuration for all machines in this service
  perMachine = _: {
    nixosModule =
      { pkgs, config, ... }:
      let
        # Use the helper to check if Traefik auth is needed
        needsAuth = traefikLib.needsTraefikAuth {
          serviceName = "grafana";
          inherit config;
        };
      in
      {
        # Ensure grafana package is available
        environment.systemPackages = [ pkgs.grafana ];

        # Create vars generator for Grafana secrets
        clan.core.vars.generators = lib.mkMerge [
          {
            grafana = {
              files.admin_password = {
                owner = "grafana";
                group = "grafana";
                mode = "0400";
              };
              files.secret_key = {
                owner = "grafana";
                group = "grafana";
                mode = "0400";
              };
              runtimeInputs = [ pkgs.coreutils ];
              prompts.admin_password = {
                description = "Grafana admin password";
                type = "hidden";
                persist = true;
              };
              script = ''
                cat "$prompts"/admin_password > "$out"/admin_password
                # Generate a random secret key if not provided
                if [ ! -f "$out"/secret_key ]; then
                  dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 > "$out"/secret_key
                fi
              '';
            };
          }

          # Use the helper to create Traefik auth generator if needed
          (lib.mkIf needsAuth (
            traefikLib.mkTraefikAuthGenerator {
              serviceName = "grafana";
              inherit pkgs;
            }
          ))
        ];
      };
  };
}
