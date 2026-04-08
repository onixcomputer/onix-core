{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };

  # Generate an Alloy River config block for a single file scrape.
  #   { name = "varlogs"; path = "/var/log/*.log"; labels = { job = "varlogs"; }; }
  mkFileScrapeBlock = scrape: ''
    local.file_match "${scrape.name}" {
      path_targets = [{
        __path__ = "${scrape.path}",
        ${lib.concatStringsSep "\n    " (
          lib.mapAttrsToList (k: v: ''${k} = "${v}",'') (scrape.labels or { })
        )}
      }]
    }

    loki.source.file "${scrape.name}" {
      targets    = local.file_match.${scrape.name}.targets
      forward_to = [loki.write.default.receiver]
    }
  '';

  # Generate a complete Alloy config that scrapes the systemd journal +
  # optional file paths and pushes everything to a Loki endpoint.
  mkAlloyConfig =
    {
      lokiUrl,
      hostname,
      additionalFileScrapes ? [ ],
      alloyExtraConfig ? "",
    }:
    ''
      loki.write "default" {
        endpoint {
          url = "${lokiUrl}/loki/api/v1/push"
        }
      }

      loki.relabel "journal" {
        forward_to = []
        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
        rule {
          source_labels = ["__journal__hostname"]
          target_label  = "hostname"
        }
      }

      loki.source.journal "systemd" {
        forward_to    = [loki.write.default.receiver]
        relabel_rules = loki.relabel.journal.rules
        max_age       = "12h"
        labels        = {
          job  = "systemd-journal",
          host = "${hostname}",
        }
      }

      ${lib.concatMapStringsSep "\n" mkFileScrapeBlock additionalFileScrapes}
      ${alloyExtraConfig}
    '';
in
{
  _class = "clan.service";
  manifest = {
    name = "loki";
    readme = "Loki log aggregation system for centralized log storage and querying";
  };

  roles = {
    # ── Loki server (+ optional Alloy log collector) ────────────────────
    server = {
      description = "Loki log aggregation server that stores and queries logs";
      interface = mkSettings.mkInterface schema.server;

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, lib, ... }:
            let
              settings = extendSettings { };
              inherit (settings)
                enableAlloy
                lokiUrl
                additionalFileScrapes
                alloyExtraConfig
                ;

              # Strip clan-specific keys before passing to services.loki
              lokiConfig = builtins.removeAttrs settings [
                "enableAlloy"
                "lokiUrl"
                "additionalFileScrapes"
                "alloyExtraConfig"
              ];
            in
            {
              services.loki = lib.mkMerge [
                { enable = true; }
                lokiConfig
              ];

              # Alloy replaces promtail for log collection
              services.alloy = lib.mkIf enableAlloy {
                enable = true;
              };

              environment.etc."alloy/config.alloy" = lib.mkIf enableAlloy {
                text = mkAlloyConfig {
                  inherit lokiUrl additionalFileScrapes alloyExtraConfig;
                  hostname = config.networking.hostName;
                };
              };

              networking.firewall.allowedTCPPorts = [
                (config.services.loki.configuration.server.http_listen_port or 3100)
              ];
            };
        };
    };

    # ── Alloy log shipper (sends logs to a remote Loki) ────────────────
    alloy = {
      description = "Grafana Alloy log shipper that sends logs to Loki server";
      interface = mkSettings.mkInterface schema.alloy;

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, ... }:
            let
              settings = extendSettings { };
              inherit (settings) lokiUrl additionalFileScrapes alloyExtraConfig;
            in
            {
              services.alloy.enable = true;

              environment.etc."alloy/config.alloy".text = mkAlloyConfig {
                inherit lokiUrl additionalFileScrapes alloyExtraConfig;
                hostname = config.networking.hostName;
              };
            };
        };
    };
  };

  # Packages available on every machine in this service
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          loki
          grafana-alloy
        ];
      };
  };
}
