{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "prometheus";
    readme = "Prometheus monitoring system for metrics collection and alerting";
  };

  # Define available roles
  roles = {
    # Prometheus server role
    server = {
      description = "Prometheus monitoring server that collects and stores metrics";
      interface =
        { lib, ... }:
        let
          ms = import ../../lib/mk-settings.nix { inherit lib; };
          base = ms.mkInterface schema.server;
        in
        base
        // {
          # dnsDiscovery uses NixOS submodule — override the schema-generated record type
          options = base.options // {
            dnsDiscovery = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    names = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      description = "DNS names to query";
                    };
                    type = lib.mkOption {
                      type = lib.types.enum [
                        "A"
                        "AAAA"
                        "SRV"
                      ];
                      default = "A";
                      description = "DNS record type to query";
                    };
                    port = lib.mkOption {
                      type = lib.types.port;
                      description = "Port to use for the targets";
                    };
                  };
                }
              );
              default = { };
              description = "DNS discovery configuration for each job";
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

              # All options have mkOption defaults — no `or` fallbacks needed.
              inherit (settings)
                enableAutoDiscovery
                discoveryMethod
                additionalScrapeConfigs
                staticTargets
                dnsDiscovery
                ;

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
                      ExecStart = "${pkgs.tailscalesd}/bin/tailscalesd --localapi --localapi_socket /var/run/tailscale/tailscaled.sock";
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
                  scrapeConfigs =
                    let
                      # Merge local exporters into the discovered configs
                      mergedConfigs =
                        let
                          # Add local node exporter to tailscale job if enabled
                          nodeExporterConfig = lib.optionals (config.services.prometheus.exporters.node.enable or false) [
                            {
                              targets = [ "localhost" ]; # Port will be added by relabel_configs
                              labels = {
                                instance = config.networking.hostName;
                                __meta_tailscale_device_name = config.networking.hostName;
                                __meta_tailscale_device_hostname = config.networking.hostName;
                                __meta_tailscale_device_os = "nixos";
                                source = "local";
                              };
                            }
                          ];

                          # Add local systemd exporter to tailscale job if enabled
                          systemdExporterConfig =
                            lib.optionals (config.services.prometheus.exporters.systemd.enable or false)
                              [
                                {
                                  targets = [ "localhost" ]; # Port will be added by relabel_configs
                                  labels = {
                                    instance = config.networking.hostName;
                                    __meta_tailscale_device_name = config.networking.hostName;
                                    source = "local";
                                  };
                                }
                              ];

                          # Function to merge local configs into discovery configs
                          mergeLocalIntoDiscovery =
                            configs:
                            map (
                              job:
                              if job.job_name == "tailscale-node-exporter" && nodeExporterConfig != [ ] then
                                job
                                // {
                                  static_configs = (job.static_configs or [ ]) ++ nodeExporterConfig;
                                }
                              else if job.job_name == "tailscale-systemd-exporter" && systemdExporterConfig != [ ] then
                                job
                                // {
                                  static_configs = (job.static_configs or [ ]) ++ systemdExporterConfig;
                                }
                              else
                                job
                            ) configs;
                        in
                        if enableAutoDiscovery && discoveryMethod == "tailscale" then
                          mergeLocalIntoDiscovery autoDiscoveredConfigs
                        else
                          autoDiscoveredConfigs;

                      allConfigs = mergedConfigs ++ staticConfigs ++ additionalScrapeConfigs;
                    in
                    lib.mkIf (allConfigs != [ ]) allConfigs;
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
      description = "Prometheus exporter that exposes metrics for collection";
      interface = mkSettings.mkInterface schema.exporter;

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
                "enabledCollectors"
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
