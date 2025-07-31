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
    enum
    ;
in
{
  _class = "clan.service";
  manifest.name = "prometheus";

  # Define available roles
  roles = {
    # Prometheus server role
    server = {
      interface = {
        # Allow freeform configuration that maps directly to services.prometheus
        freeformType = attrsOf anything;

        options = {
          # Clan-specific options for auto-discovery
          enableAutoDiscovery = mkOption {
            type = bool;
            default = true;
            description = "Whether to automatically discover and scrape exporters in the clan";
          };

          # Discovery method to use
          discoveryMethod = mkOption {
            type = enum [
              "none"
              "tailscale"
              "dns"
              "static"
            ];
            default = "none";
            description = ''
              Method to use for service discovery:
              - none: No auto-discovery, only use additionalScrapeConfigs
              - tailscale: Use tailscalesd for discovery (requires Tailscale)
              - dns: Use DNS-based discovery
              - static: Use static targets from staticTargets option
            '';
          };

          # Wrapper for common scrape configs
          additionalScrapeConfigs = mkOption {
            type = listOf anything;
            default = [ ];
            description = "Additional scrape configurations to merge with auto-discovered ones";
          };

          # Static configs for static discovery method
          staticTargets = mkOption {
            type = attrsOf (listOf str);
            default = { };
            description = "Static targets for each job when using 'static' discovery method";
            example = {
              node = [
                "192.168.1.10:9100"
                "192.168.1.11:9100"
              ];
              systemd = [
                "192.168.1.10:9558"
                "192.168.1.11:9558"
              ];
            };
          };

          # DNS discovery options
          dnsDiscovery = mkOption {
            type = attrsOf (
              lib.types.submodule {
                options = {
                  names = mkOption {
                    type = listOf str;
                    description = "DNS names to query";
                  };
                  type = mkOption {
                    type = enum [
                      "A"
                      "AAAA"
                      "SRV"
                    ];
                    default = "A";
                    description = "DNS record type to query";
                  };
                  port = mkOption {
                    type = lib.types.port;
                    description = "Port to use for the targets";
                  };
                };
              }
            );
            default = { };
            description = "DNS discovery configuration for each job";
            example = {
              node = {
                names = [ "*.monitoring.example.com" ];
                type = "A";
                port = 9100;
              };
            };
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
              pkgs,
              ...
            }:
            let
              # Get the extended settings
              settings = extendSettings { };

              # Extract clan-specific options
              enableAutoDiscovery = settings.enableAutoDiscovery or true;
              discoveryMethod = settings.discoveryMethod or "none";
              additionalScrapeConfigs = settings.additionalScrapeConfigs or [ ];
              staticTargets = settings.staticTargets or { };
              dnsDiscovery = settings.dnsDiscovery or { };

              # Remove clan-specific options before passing to services.prometheus
              prometheusConfig = builtins.removeAttrs settings [
                "enableAutoDiscovery"
                "discoveryMethod"
                "additionalScrapeConfigs"
                "staticTargets"
                "dnsDiscovery"
              ];

              # Check if Tailscale is available
              hasTailscale = config.services.tailscale.enable or false;

              # Tailscale discovery configs
              tailscaleConfigs = [
                {
                  job_name = "tailscale-node-exporter";
                  http_sd_configs = [
                    {
                      url = "http://localhost:9242/";
                    }
                  ];
                  relabel_configs = [
                    # Add port 9100 for node exporter
                    {
                      source_labels = [ "__address__" ];
                      regex = "(.*)";
                      replacement = "\${1}:9100";
                      target_label = "__address__";
                    }
                    # Keep the device name as instance label
                    {
                      source_labels = [ "__meta_tailscale_device_name" ];
                      target_label = "instance";
                    }
                    # Add OS label
                    {
                      source_labels = [ "__meta_tailscale_device_os" ];
                      target_label = "os";
                    }
                    # Add tailscale tags as labels
                    {
                      source_labels = [ "__meta_tailscale_device_tag" ];
                      regex = "tag:(.+)";
                      target_label = "tailscale_tag_\${1}";
                    }
                  ];
                }
                {
                  job_name = "tailscale-systemd-exporter";
                  http_sd_configs = [
                    {
                      url = "http://localhost:9242/";
                    }
                  ];
                  relabel_configs = [
                    # Add port 9558 for systemd exporter
                    {
                      source_labels = [ "__address__" ];
                      regex = "(.*)";
                      replacement = "\${1}:9558";
                      target_label = "__address__";
                    }
                    {
                      source_labels = [ "__meta_tailscale_device_name" ];
                      target_label = "instance";
                    }
                  ];
                }
              ];

              # DNS discovery configs
              dnsConfigs = lib.mapAttrsToList (job: cfg: {
                job_name = "${job}-dns";
                dns_sd_configs = [
                  {
                    inherit (cfg) names type port;
                    refresh_interval = "30s";
                  }
                ];
              }) dnsDiscovery;

              # Static configs
              staticConfigs = lib.mapAttrsToList (job: targets: {
                job_name = job;
                static_configs = [
                  {
                    inherit targets;
                  }
                ];
              }) staticTargets;

              # Select discovery configs based on method
              autoDiscoveredConfigs =
                if enableAutoDiscovery then
                  if discoveryMethod == "tailscale" && hasTailscale then
                    tailscaleConfigs
                  else if discoveryMethod == "dns" then
                    dnsConfigs
                  else if discoveryMethod == "static" then
                    staticConfigs
                  else
                    [ ]
                else
                  [ ];

            in
            {
              # Warn if auto-discovery is enabled but requirements aren't met
              warnings =
                lib.optional (enableAutoDiscovery && discoveryMethod == "tailscale" && !hasTailscale)
                  "Prometheus Tailscale discovery is enabled but Tailscale is not available. Discovery will be disabled.";

              # Enable tailscalesd service for Tailscale discovery
              systemd.services.tailscalesd =
                lib.mkIf (enableAutoDiscovery && discoveryMethod == "tailscale" && hasTailscale)
                  {
                    description = "Tailscale Service Discovery for Prometheus";
                    after = [
                      "network.target"
                      "tailscaled.service"
                    ];
                    wantedBy = [ "multi-user.target" ];
                    serviceConfig = {
                      ExecStart = "${pkgs.tailscalesd}/bin/tailscalesd -localapi -localapi_socket /var/run/tailscale/tailscaled.sock";
                      Restart = "always";
                      RestartSec = 10;
                      User = "prometheus";
                      Group = "prometheus";
                      # Allow access to tailscale socket
                      SupplementaryGroups = [ "tailscale" ];
                    };
                  };

              # Create tailscale group if it doesn't exist
              users.groups.tailscale = lib.mkIf (enableAutoDiscovery && discoveryMethod == "tailscale") { };

              # Enable Prometheus with the freeform configuration
              services.prometheus = lib.mkMerge [
                { enable = true; }
                prometheusConfig
                {
                  scrapeConfigs = lib.mkIf (
                    autoDiscoveredConfigs != [ ] || additionalScrapeConfigs != [ ] || staticConfigs != [ ]
                  ) (autoDiscoveredConfigs ++ staticConfigs ++ additionalScrapeConfigs);
                }
              ];

              # Open firewall for Prometheus
              networking.firewall.allowedTCPPorts = [
                (prometheusConfig.port or 9090)
              ];
            };
        };
    };

    # Exporter role for various Prometheus exporters
    exporter = {
      interface = {
        # Allow freeform configuration for the specific exporter
        freeformType = attrsOf anything;

        options = {
          exporterType = mkOption {
            type = enum [
              "node"
              "systemd"
              "nginx"
              "postgres"
              "redis"
              "blackbox"
              "snmp"
              "json"
              "domain"
              # Add more as needed
            ];
            description = "Type of Prometheus exporter to enable";
          };

          # Common exporter options
          port = mkOption {
            type = nullOr lib.types.port;
            default = null;
            description = "Port for the exporter (uses default if not specified)";
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, lib, ... }:
            let
              settings = extendSettings { };
              inherit (settings) exporterType;

              # Remove our wrapper options
              exporterConfig = builtins.removeAttrs settings [
                "exporterType"
                "port"
              ];

              # Apply port if specified
              finalConfig =
                if settings.port != null then exporterConfig // { inherit (settings) port; } else exporterConfig;

            in
            {
              # Enable the specific exporter with freeform config
              services.prometheus.exporters.${exporterType} = lib.mkMerge [
                { enable = true; }
                finalConfig
              ];

              # Open firewall for the exporter
              networking.firewall.allowedTCPPorts =
                lib.optional config.services.prometheus.exporters.${exporterType}.enable
                  config.services.prometheus.exporters.${exporterType}.port;
            };
        };
    };
  };

  # Common configuration for all machines in this service
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        # Ensure prometheus package is available
        environment.systemPackages = [ pkgs.prometheus ];
      };
  };
}
