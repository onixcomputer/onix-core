{ lib, ... }:
let
  inherit (lib) mkOption mkDefault mkIf;
  inherit (lib.types)
    nullOr
    attrsOf
    anything
    str
    ;

  # Import Traefik integration helpers
  traefikLib = import ../traefik/lib.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest.name = "vaultwarden";

  roles = {
    server = {
      interface = {
        # Freeform module - any attribute becomes a Vaultwarden environment variable
        freeformType = attrsOf anything;

        options = {
          # Optional secret management
          adminTokenFile = mkOption {
            type = nullOr str;
            default = null;
            description = "Path to file containing the admin token";
          };

          # Traefik integration using shared options
          traefik = traefikLib.mkTraefikOptions;
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, ... }:
            let
              localSettings = extendSettings {
                adminTokenFile = mkDefault config.clan.core.vars.generators.vaultwarden.files.admin_token.path;

                # Minimal defaults
                DOMAIN = mkDefault "https://vaultwarden.localhost";
                ROCKET_PORT = mkDefault 8222;
                WEBSOCKET_ENABLED = mkDefault true;
                WEBSOCKET_PORT = mkDefault 3012;
              };

              # Extract known options from freeform settings
              inherit (localSettings) adminTokenFile;
              traefikConfig = localSettings.traefik or { };

              # Everything else is a Vaultwarden environment variable
              environment = removeAttrs localSettings [
                "adminTokenFile"
                "traefik"
              ];
            in
            {
              services.vaultwarden = {
                enable = true;
                config = environment;
              };

              # Set admin token if provided
              systemd.services.vaultwarden = mkIf (adminTokenFile != null) {
                serviceConfig = {
                  LoadCredential = [ "admin_token:${adminTokenFile}" ];
                };
                environment.ADMIN_TOKEN_FILE = "%d/admin_token";
              };

              # Use the reusable Traefik integration helper
              services.traefik = lib.mkMerge [
                (traefikLib.mkTraefikIntegration {
                  serviceName = "vaultwarden";
                  servicePort = environment.ROCKET_PORT;
                  inherit traefikConfig config;
                  # Vaultwarden needs websocket support
                  extraRouterConfig = mkIf (environment.WEBSOCKET_ENABLED or false) {
                    middlewares = (traefikConfig.middlewares or [ ]) ++ [ "vaultwarden-websocket" ];
                  };
                })

                # Add websocket middleware if needed
                {
                  dynamicConfigOptions.http.middlewares =
                    mkIf
                      (
                        (environment.WEBSOCKET_ENABLED or false)
                        && (config.services.traefik.enable or false)
                        && (traefikConfig.enable or true)
                        && (traefikConfig.host or null) != null
                      )
                      {
                        vaultwarden-websocket = {
                          headers.customRequestHeaders = {
                            "X-Forwarded-Proto" = "https";
                          };
                        };
                      };
                }
              ];

              # Open firewall ports if configured
              networking.firewall.allowedTCPPorts =
                lib.optional (environment ? ROCKET_PORT) environment.ROCKET_PORT
                ++ lib.optional (environment ? WEBSOCKET_PORT) environment.WEBSOCKET_PORT;
            };
        };
    };
  };

  # Common configuration for all machines with vaultwarden
  perMachine = _: {
    nixosModule =
      { pkgs, config, ... }:
      let
        # Use the helper to check if Traefik auth is needed
        needsAuth = traefikLib.needsTraefikAuth {
          serviceName = "vaultwarden";
          inherit config;
        };
      in
      {
        # Create vars generator for Vaultwarden admin token
        clan.core.vars.generators = lib.mkMerge [
          {
            vaultwarden = {
              files.admin_token = { };
              runtimeInputs = with pkgs; [
                coreutils
                openssl
              ];
              script = ''
                openssl rand -base64 48 > "$out/admin_token"
              '';
            };
          }

          # Use the helper to create Traefik auth generator if needed
          (lib.mkIf needsAuth (
            traefikLib.mkTraefikAuthGenerator {
              serviceName = "vaultwarden";
              inherit pkgs;
            }
          ))
        ];
      };
  };
}
