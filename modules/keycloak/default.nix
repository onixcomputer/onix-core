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

          terraformBackend = mkOption {
            type = lib.types.enum [
              "local"
              "s3"
            ];
            default = "local";
            description = "Terraform state backend type (local or s3/garage)";
          };

          terraformAutoApply = mkOption {
            type = lib.types.bool;
            default = false;
            description = "Automatically apply terraform on service start";
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
              terraformBackend = settings.terraformBackend or "local";
              terraformAutoApply = settings.terraformAutoApply or false; # Default 5 minutes
              # Use terranix for terraform configuration generation

              generatorName = "keycloak-${instanceName}";
              dbPasswordFile = config.clan.core.vars.generators.${generatorName}.files.db_password.path;
              adminPasswordFile = config.clan.core.vars.generators.${generatorName}.files.admin_password.path;

              # OpenTofu library functions
              opentofu = import ../../lib/opentofu/default.nix { inherit lib pkgs; };

              # Enhanced terranix integration
              terranix = import ../../lib/opentofu/terranix.nix { inherit lib pkgs; };

              # Dependencies for terraform deployment
              deploymentDependencies = [
                "keycloak.service"
                "keycloak-password-sync.service"
              ]
              ++ lib.optionals (terraformBackend == "s3") [ "garage-terraform-init-${instanceName}.service" ];
            in
            {
              services = {
                keycloak = {
                  enable = true;

                  # Use predictable bootstrap password (updated by sync service to clan vars)
                  initialAdminPassword = "TemporaryBootstrapPassword123!";

                  settings = {
                    hostname = domain;
                    proxy-headers = "xforwarded";
                    http-enabled = true;
                    http-port = 8080;
                    # Enable health checks on management port
                    health-enabled = true;
                    http-management-port = 9000;
                    http-management-relative-path = "/management";
                  };

                  database = {
                    type = "postgresql";
                    createLocally = true;
                    passwordFile = dbPasswordFile;
                  };
                };

                postgresql.enable = true;

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
                      proxyPass = "http://localhost:8080";
                      proxyWebsockets = true;
                      extraConfig = ''
                        proxy_set_header X-Real-IP $remote_addr;
                        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                        proxy_set_header X-Forwarded-Proto https;
                        proxy_set_header X-Forwarded-Host ${domain};
                        proxy_set_header Host ${domain};
                      '';
                    };
                  };
                };
              };

              # Generate clan vars for database and admin passwords
              clan.core.vars.generators."keycloak-${instanceName}" = {
                files = {
                  db_password = {
                    deploy = true;
                  };
                  admin_password = {
                    deploy = true;
                  };
                };
                runtimeInputs = [ pkgs.pwgen ];
                script = ''
                  ${pkgs.pwgen}/bin/pwgen -s 32 1 | tr -d '\n' > "$out"/db_password
                  ${pkgs.pwgen}/bin/pwgen -s 32 1 | tr -d '\n' > "$out"/admin_password
                '';
              };

              # Apply the blocking deployment pattern using terranix-enhanced OpenTofu library
              # Add activation script to trigger terraform deployment on configuration changes
              system.activationScripts."keycloak-terraform-reset-${instanceName}" = lib.mkIf terraformAutoApply (
                let
                  terraformConfigJson = terranix.generateTerranixJson {
                    module = ./terranix-config.nix;
                    moduleArgs = {
                      inherit lib settings;
                    };
                    fileName = "keycloak-terraform-${instanceName}.json";
                    validate = true;
                    debug = false;
                  };
                in
                opentofu.mkActivationScript {
                  serviceName = "keycloak";
                  inherit instanceName;
                  terraformConfigPath = terraformConfigJson;
                }
              );

              systemd.services =
                (
                  let
                    baseService = terranix.mkTerranixDeploymentService {
                      serviceName = "keycloak";
                      inherit instanceName;

                      # Use the new terranix module
                      terranixModule = ./terranix-config.nix;
                      moduleArgs = {
                        inherit lib settings;
                      };

                      # Map terraform variables to clan vars
                      credentialMapping = {
                        "admin_password" = "admin_password";
                      };
                      dependencies = deploymentDependencies;
                      backendType = terraformBackend;
                      timeoutSec = "10m";

                      # Enhanced terranix options
                      validateConfig = true;
                      debugMode = false;
                      prettyPrintJson = false;

                      preTerraformScript = ''
                        echo 'Using clan vars admin password for terraform authentication'
                      '';
                    };
                  in
                  baseService
                )
                // (lib.optionalAttrs (terraformBackend == "s3") (
                  opentofu.mkGarageInitService {
                    serviceName = "keycloak";
                    inherit instanceName config;
                  }
                ))
                // {
                  # Password sync service - ensures both admin and database passwords match clan vars
                  "keycloak-password-sync" = {
                    description = "Sync Keycloak admin and database passwords to clan vars";
                    after = [
                      "keycloak.service"
                      "postgresql.service"
                    ];
                    requires = [
                      "keycloak.service"
                      "postgresql.service"
                    ];
                    wantedBy = [ "multi-user.target" ];

                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      StateDirectory = "keycloak-password-sync";
                      WorkingDirectory = "/var/lib/keycloak-password-sync";
                      # Load both clan vars passwords
                      LoadCredential = [
                        "admin_password:${adminPasswordFile}"
                        "db_password:${dbPasswordFile}"
                      ];
                    };

                    path = with pkgs; [
                      keycloak
                      curl
                      jq
                      postgresql
                      sudo
                    ];

                    script = ''
                      set -euo pipefail

                      echo "Syncing Keycloak admin and database passwords to clan vars..."

                      # Read clan vars passwords
                      ADMIN_PASSWORD=$(cat "$CREDENTIALS_DIRECTORY/admin_password")
                      DB_PASSWORD=$(cat "$CREDENTIALS_DIRECTORY/db_password")

                      echo "=== Database Password Sync ==="

                      # Update PostgreSQL keycloak user password to match clan vars
                      echo "Updating PostgreSQL keycloak user password..."
                      sudo -u postgres psql -c "ALTER USER keycloak PASSWORD '$DB_PASSWORD';" || {
                        echo "⚠ Failed to update PostgreSQL password"
                        exit 1
                      }
                      echo "✓ PostgreSQL keycloak user password updated"

                      echo "=== Keycloak Admin Password Sync ==="

                      # Wait for Keycloak to be ready
                      for i in {1..30}; do
                        if curl -sf http://localhost:8080/realms/master >/dev/null 2>&1; then
                          break
                        fi
                        echo "Waiting for Keycloak... (attempt $i/30)"
                        sleep 2
                      done

                      # Use Keycloak admin CLI to ensure password matches clan vars
                      export JAVA_HOME="${pkgs.openjdk_headless}"

                      echo "Testing current admin password..."
                      if ${pkgs.keycloak}/bin/kcadm.sh config credentials \
                        --server http://localhost:8080 \
                        --realm master \
                        --user admin \
                        --password "$ADMIN_PASSWORD" 2>/dev/null; then

                        echo "✓ Admin password already matches clan vars - no update needed"
                        touch /var/lib/keycloak-password-sync/.sync-complete
                        exit 0
                      fi

                      echo "Admin password doesn't match clan vars - updating..."

                      # Create a comprehensive list: previous clan vars passwords from state + known fallbacks
                      POSSIBLE_PASSWORDS=()

                      # Add any previous password from our state files
                      if [ -f /var/lib/keycloak-password-sync/.last-password ]; then
                        LAST_PASSWORD=$(cat /var/lib/keycloak-password-sync/.last-password 2>/dev/null || true)
                        if [ -n "$LAST_PASSWORD" ]; then
                          POSSIBLE_PASSWORDS+=("$LAST_PASSWORD")
                        fi
                      fi

                      # Add known fallback passwords
                      POSSIBLE_PASSWORDS+=("TemporaryBootstrapPassword123!" "TestPassword456!" "Hello123" "admin" "password")

                      for CURRENT_PASSWORD in "''${POSSIBLE_PASSWORDS[@]}"; do
                        echo "Trying to connect with known password..."
                        if ${pkgs.keycloak}/bin/kcadm.sh config credentials \
                          --server http://localhost:8080 \
                          --realm master \
                          --user admin \
                          --password "$CURRENT_PASSWORD" 2>/dev/null; then

                          echo "✓ Connected, updating admin password to clan vars..."

                          # Update admin password to clan vars password
                          ${pkgs.keycloak}/bin/kcadm.sh set-password \
                            --server http://localhost:8080 \
                            --realm master \
                            --target-realm master \
                            --username admin \
                            --new-password "$ADMIN_PASSWORD"

                          echo "✓ Admin password updated to clan vars successfully"

                          # Save the new password for future reference
                          echo "$ADMIN_PASSWORD" > /var/lib/keycloak-password-sync/.last-password

                          touch /var/lib/keycloak-password-sync/.sync-complete
                          exit 0
                        fi
                      done

                      echo "⚠ Could not connect with any known password"
                      echo "Manual intervention may be required to reset admin password"
                      touch /var/lib/keycloak-password-sync/.sync-failed
                      exit 1
                    '';
                  };

                  # Basic service startup order
                  keycloak = {
                    after = [ "postgresql.service" ];
                    requires = [ "postgresql.service" ];

                    preStart = ''
                      while ! ${config.services.postgresql.package}/bin/pg_isready -h localhost; do
                        echo "Waiting for PostgreSQL to be ready..."
                        sleep 2
                      done
                      echo "PostgreSQL ready. Starting Keycloak."
                    '';
                  };

                };

              # Note: Activation script and deployment service are now provided by the generic deployment pattern

              # Helper commands for terraform management
              environment.systemPackages = opentofu.mkHelperScripts {
                serviceName = "keycloak";
                inherit instanceName;
              };
            };
        };
    };
  };
}
