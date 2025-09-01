{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) str attrsOf anything;
in
{
  _class = "clan.service";
  manifest = {
    name = "keycloak";
    description = "Enterprise Identity and Access Management";
    categories = [
      "Authentication"
      "Security"
    ];
  };

  roles = {
    server = {
      interface = {
        freeformType = attrsOf anything;

        options = {
          domain = mkOption {
            type = str;
            description = "Domain name for the Keycloak instance";
            example = "auth.company.com";
          };

          nginxPort = mkOption {
            type = lib.types.port;
            default = 9080;
            description = "Nginx proxy port for Keycloak";
          };
        };
      };

      perInstance =
        { instanceName, extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              pkgs,
              ...
            }:
            let
              settings = extendSettings { };
              inherit (settings) domain;
              nginxPort = settings.nginxPort or 9080;

              keycloakSettings = builtins.removeAttrs settings [
                "domain"
                "nginxPort"
              ];

              generatorName = "keycloak-${instanceName}";
              dbPasswordFile = config.clan.core.vars.generators.${generatorName}.files.db_password.path;
            in
            {
              services = {
                keycloak = {
                  enable = true;

                  settings = {
                    hostname = domain;
                    proxy-headers = "xforwarded"; # Trust X-Forwarded headers from nginx
                    http-enabled = true; # HTTP only, nginx handles HTTPS
                    http-port = 8080;
                  }
                  // (keycloakSettings.settings or { });

                  database = {
                    type = "postgresql";
                    createLocally = true;
                    passwordFile = dbPasswordFile;
                  };

                  initialAdminPassword = "admin-${instanceName}";
                }
                // (builtins.removeAttrs keycloakSettings [
                  "settings"
                  "database"
                ]);

                nginx = {
                  enable = true;
                  recommendedTlsSettings = true;
                  recommendedOptimisation = true;
                  recommendedGzipSettings = true;
                  recommendedProxySettings = true;

                  virtualHosts."keycloak-${instanceName}" = {
                    listen = [
                      {
                        addr = "0.0.0.0";
                        port = nginxPort;
                      }
                    ];
                    locations."/" = {
                      proxyPass = "http://localhost:${toString config.services.keycloak.settings.http-port}";
                      proxyWebsockets = true;
                      extraConfig = ''
                        # Pass real client IP and protocol information
                        proxy_set_header X-Real-IP $remote_addr;
                        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                        proxy_set_header X-Forwarded-Proto https; # Always tell Keycloak it's HTTPS
                        proxy_set_header X-Forwarded-Host ${domain};
                        proxy_set_header Host ${domain};
                      '';
                    };
                  };
                };
              };

              clan.core.vars.generators."keycloak-${instanceName}" = {
                files.db_password = {
                  deploy = true;
                };
                runtimeInputs = [ pkgs.pwgen ];
                script = ''
                  ${pkgs.pwgen}/bin/pwgen -s 32 1 | tr -d '\n' > "$out"/db_password
                '';
              };
            };
        };
    };
  };
}
