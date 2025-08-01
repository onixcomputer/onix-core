{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    bool
    str
    listOf
    attrsOf
    anything
    ;
in
{
  _class = "clan.service";
  manifest.name = "loki";

  # Define available roles
  roles = {
    # Loki server role
    server = {
      interface = {
        # Allow freeform configuration that maps directly to services.loki
        freeformType = attrsOf anything;

        options = {
          # Minimal clan-specific options
          enablePromtail = mkOption {
            type = bool;
            default = true;
            description = "Whether to enable Promtail for log collection";
          };

          # Promtail configuration
          promtailConfig = mkOption {
            type = attrsOf anything;
            default = { };
            description = "Promtail configuration (passed to services.promtail.configuration)";
          };
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
              enablePromtail = settings.enablePromtail or true;
              promtailConfig = settings.promtailConfig or { };

              # Remove clan-specific options before passing to services.loki
              lokiConfig = builtins.removeAttrs settings [
                "enablePromtail"
                "promtailConfig"
              ];

              # Default Promtail configuration for systemd journal
              defaultPromtailConfig = {
                server = {
                  http_listen_port = 9080;
                  grpc_listen_port = 0;
                };

                positions = {
                  filename = "/var/cache/promtail/positions.yaml";
                };

                clients = [
                  {
                    url = "http://localhost:3100/loki/api/v1/push";
                  }
                ];

                scrape_configs = [
                  {
                    job_name = "systemd-journal";
                    journal = {
                      max_age = "12h";
                      labels = {
                        job = "systemd-journal";
                        host = config.networking.hostName;
                      };
                    };
                    relabel_configs = [
                      {
                        source_labels = [ "__journal__systemd_unit" ];
                        target_label = "unit";
                      }
                      {
                        source_labels = [ "__journal__hostname" ];
                        target_label = "hostname";
                      }
                    ];
                  }
                ];
              };

            in
            {
              # Enable Loki with the freeform configuration
              services.loki = lib.mkMerge [
                {
                  enable = true;
                }
                lokiConfig
              ];

              # Enable Promtail if requested
              services.promtail = lib.mkIf enablePromtail {
                enable = true;
                configuration = lib.recursiveUpdate defaultPromtailConfig promtailConfig;
              };

              # Open firewall for Loki and Promtail
              networking.firewall.allowedTCPPorts = lib.mkMerge [
                [ (config.services.loki.configuration.server.http_listen_port or 3100) ]
                (lib.mkIf enablePromtail [ (promtailConfig.server.http_listen_port or 9080) ])
              ];

              # Ensure promtail cache directory exists
              systemd.tmpfiles.rules = lib.mkIf enablePromtail [
                "d '/var/cache/promtail' 0700 promtail promtail - -"
              ];
            };
        };
    };

    # Promtail client role for log collection
    promtail = {
      interface = {
        # Allow freeform configuration that maps directly to services.promtail
        freeformType = attrsOf anything;

        options = {
          # Loki server URL
          lokiUrl = mkOption {
            type = str;
            default = "http://localhost:3100";
            description = "URL of the Loki server to send logs to";
          };

          # Additional scrape configs
          additionalScrapeConfigs = mkOption {
            type = listOf anything;
            default = [ ];
            description = "Additional Promtail scrape configurations";
          };
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
              lokiUrl = settings.lokiUrl or "http://localhost:3100";
              additionalScrapeConfigs = settings.additionalScrapeConfigs or [ ];

              # Remove clan-specific options before passing to services.promtail
              promtailConfig = builtins.removeAttrs settings [
                "lokiUrl"
                "additionalScrapeConfigs"
              ];

              # Default Promtail configuration
              defaultConfig = {
                server = {
                  http_listen_port = 9080;
                  grpc_listen_port = 0;
                };

                positions = {
                  filename = "/var/cache/promtail/positions.yaml";
                };

                clients = [
                  {
                    url = "${lokiUrl}/loki/api/v1/push";
                  }
                ];

                scrape_configs = [
                  {
                    job_name = "systemd-journal";
                    journal = {
                      max_age = "12h";
                      labels = {
                        job = "systemd-journal";
                        host = config.networking.hostName;
                      };
                    };
                    relabel_configs = [
                      {
                        source_labels = [ "__journal__systemd_unit" ];
                        target_label = "unit";
                      }
                      {
                        source_labels = [ "__journal__hostname" ];
                        target_label = "hostname";
                      }
                    ];
                  }
                ]
                ++ additionalScrapeConfigs;
              };

            in
            {
              # Enable Promtail with the freeform configuration
              services.promtail = lib.mkMerge [
                {
                  enable = true;
                  configuration = lib.recursiveUpdate defaultConfig (promtailConfig.configuration or { });
                }
                (builtins.removeAttrs promtailConfig [ "configuration" ])
              ];

              # Open firewall for Promtail metrics
              networking.firewall.allowedTCPPorts = [
                (promtailConfig.configuration.server.http_listen_port or defaultConfig.server.http_listen_port)
              ];

              # Ensure promtail cache directory exists
              systemd.tmpfiles.rules = [
                "d '/var/cache/promtail' 0700 promtail promtail - -"
              ];
            };
        };
    };
  };

  # Common configuration for all machines in this service
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        # Ensure loki and promtail packages are available
        environment.systemPackages = with pkgs; [
          loki
          promtail
        ];
      };
  };
}
