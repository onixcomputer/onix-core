{ lib, ... }:
let
  inherit (lib) mkDefault;
  inherit (lib.types) attrsOf anything;
in
{
  _class = "clan.service";
  manifest = {
    name = "homepage-dashboard";
    readme = "Homepage dashboard service for customizable web portal and service links";
  };

  roles = {
    server = {
      description = "Homepage dashboard server that provides a customizable web portal";
      interface = {
        # Freeform module - any attribute becomes a homepage-dashboard setting
        freeformType = attrsOf anything;
      };

      perInstance =
        { extendSettings, exports, ... }:
        let
          baseSettings = extendSettings {
            listenPort = mkDefault 8082;
          };
          serverPort = baseSettings.listenPort or 8082;
        in
        {
          exports.serviceEndpoints.homepage = {
            url = "http://localhost:${toString serverPort}";
            port = serverPort;
          };
          nixosModule =
            { lib, ... }:
            let
              # Build auto-discovered service entries from exports
              discoveredServices =
                let
                  instances = exports.instances or { };

                  # Map export endpoint names to display info
                  serviceDisplayInfo = {
                    vaultwarden = {
                      name = "Vaultwarden";
                      icon = "bitwarden.png";
                      description = "Password manager";
                    };
                    prometheus = {
                      name = "Prometheus";
                      icon = "prometheus.png";
                      description = "Metrics collection";
                    };
                    grafana = {
                      name = "Grafana";
                      icon = "grafana.png";
                      description = "Metrics visualization";
                    };
                    loki = {
                      name = "Loki";
                      icon = "loki.png";
                      description = "Log aggregation";
                    };
                    homepage = {
                      name = "Homepage";
                      icon = "homepage.png";
                      description = "Dashboard";
                    };
                    ollama = {
                      name = "Ollama";
                      icon = "ollama.png";
                      description = "LLM inference";
                    };
                    calibre = {
                      name = "Calibre";
                      icon = "calibre.png";
                      description = "E-book library";
                    };
                    clonadic = {
                      name = "Clonadic";
                      icon = "spreadsheet.png";
                      description = "LLM spreadsheet";
                    };
                  };

                  # Collect all exported service endpoints
                  allEndpoints = lib.foldlAttrs (
                    acc: _instanceName: instanceExports:
                    let
                      endpoints = instanceExports.serviceEndpoints or { };
                    in
                    acc
                    // (lib.mapAttrs (epName: ep: {
                      inherit (ep) url port;
                      displayInfo =
                        serviceDisplayInfo.${epName} or {
                          name = epName;
                          icon = "mdi-server-#fff";
                          description = epName;
                        };
                    }) endpoints)
                  ) { } instances;

                  # Convert to homepage service entries
                  serviceEntries = lib.mapAttrsToList (_name: ep: {
                    ${ep.displayInfo.name} = {
                      inherit (ep.displayInfo) icon description;
                      href = ep.url;
                      siteMonitor = ep.url;
                    };
                  }) allEndpoints;
                in
                if serviceEntries != [ ] then [ { "Discovered Services" = serviceEntries; } ] else [ ];

              localSettings = extendSettings {
                # Minimal defaults
                enable = mkDefault true;
                listenPort = mkDefault 8082;
                openFirewall = mkDefault true;

                # Default configuration structure
                settings = mkDefault {
                  title = "Dashboard";
                  background = {
                    image = "";
                    blur = "sm";
                    saturate = 50;
                    brightness = 50;
                    opacity = 50;
                  };
                };

                services = mkDefault [ ];
                widgets = mkDefault [ ];
                bookmarks = mkDefault [ ];
              };

              # Merge discovered services with manual ones
              # Manual services come first, discovered services append
              mergedSettings = localSettings // {
                services = (localSettings.services or [ ]) ++ discoveredServices;
              };
            in
            {
              services.homepage-dashboard = mergedSettings;
            };
        };
    };
  };

  # No perMachine configuration needed for homepage-dashboard
  perMachine = _: {
    nixosModule = _: { };
  };
}
