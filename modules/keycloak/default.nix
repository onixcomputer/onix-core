#Generated and edited with Claude Code Sonnet 4.5
{ inputs }:
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
      interface =
        { lib, ... }:
        {
          freeformType = lib.types.attrsOf lib.types.anything;

          options = {
            domain = lib.mkOption {
              type = lib.types.str;
              description = "Domain name for the Keycloak instance";
              example = "auth.company.com";
            };

            nginxPort = lib.mkOption {
              type = lib.types.port;
              default = 9080;
              description = "Nginx proxy port for Keycloak";
            };

            terraformBackend = lib.mkOption {
              type = lib.types.enum [
                "local"
                "s3"
              ];
              default = "local";
              description = "Terraform state backend type (local or s3/garage)";
            };

            terraformAutoApply = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Automatically apply terraform on service start";
            };

            bootstrapPassword = lib.mkOption {
              type = lib.types.str;
              default = "InitialBootstrapPassword";
              description = "Bootstrap password for initial Keycloak admin user (only used on first deployment)";
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
              lib,
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

              # Bootstrap password for initial setup - configurable for security
              bootstrapPassword = settings.bootstrapPassword or "InitialBootstrapPassword";

              # OpenTofu library functions (includes terranix utilities) - now from clan-core
              opentofu = inputs.clan-core.lib.opentofu pkgs;

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

                  # Bootstrap password - only used on first installation
                  initialAdminPassword = bootstrapPassword;

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
                  terraformConfigJson = opentofu.generateTerranixJson {
                    module = ./terranix.nix;
                    moduleArgs = {
                      inherit lib;
                      settings = settings.terraform or { };
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
                    baseService = opentofu.mkTerranixDeploymentService {
                      serviceName = "keycloak";
                      inherit instanceName;

                      # Use the terranix module for resource management
                      terranixModule = ./terranix.nix;
                      moduleArgs = {
                        inherit lib;
                        settings = settings.terraform or { };
                      };

                      # Map terraform variables to clan vars - simplified like original
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
                                                echo 'Generating terraform.tfvars from clan vars'

                                                # Generate terraform.tfvars with admin password only (like original)
                                                cat > terraform.tfvars <<EOF
                        admin_password = "$(cat "$CREDENTIALS_DIRECTORY/admin_password" | tr -d '\n\r' | sed 's/"/\\"/g')"
                        EOF

                                                echo 'Generated terraform.tfvars:'
                                                cat terraform.tfvars
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
                  # Admin password sync service - ensures admin password matches clan vars
                  "keycloak-password-sync" = {
                    description = "Sync Keycloak admin password to clan vars";
                    after = [ "keycloak.service" ];
                    requires = [ "keycloak.service" ];
                    wantedBy = [ "multi-user.target" ];

                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      StateDirectory = "keycloak-password-sync";
                      WorkingDirectory = "/var/lib/keycloak-password-sync";
                      LoadCredential = [
                        "admin_password:${adminPasswordFile}"
                      ];
                    };

                    path = with pkgs; [
                      keycloak
                      curl
                      jq
                    ];

                    script = ''
                      set -euo pipefail

                      echo "Syncing Keycloak admin password to clan vars..."

                      # Read clan vars password
                      ADMIN_PASSWORD=$(cat "$CREDENTIALS_DIRECTORY/admin_password")

                      # Wait for Keycloak to be ready
                      for i in {1..30}; do
                        if curl -sf http://localhost:8080/realms/master >/dev/null 2>&1; then
                          break
                        fi
                        echo "Waiting for Keycloak... (attempt $i/30)"
                        sleep 2
                      done

                      export JAVA_HOME="${pkgs.openjdk_headless}"

                      # Test if clan vars password already works
                      if ${pkgs.keycloak}/bin/kcadm.sh config credentials \
                        --server http://localhost:8080 \
                        --realm master \
                        --user admin \
                        --password "$ADMIN_PASSWORD" 2>/dev/null; then

                        echo "✓ Admin password already matches clan vars"
                        echo "$ADMIN_PASSWORD" > /var/lib/keycloak-password-sync/.last-password
                        touch /var/lib/keycloak-password-sync/.sync-complete
                        exit 0
                      fi

                      echo "Admin password doesn't match clan vars - trying bootstrap password..."

                      # Try bootstrap password and update to clan vars
                      if ${pkgs.keycloak}/bin/kcadm.sh config credentials \
                        --server http://localhost:8080 \
                        --realm master \
                        --user admin \
                        --password "${bootstrapPassword}" 2>/dev/null; then

                        echo "✓ Connected with bootstrap password, updating to clan vars..."

                        # Update admin password to clan vars password
                        ${pkgs.keycloak}/bin/kcadm.sh set-password \
                          --server http://localhost:8080 \
                          --realm master \
                          --target-realm master \
                          --username admin \
                          --new-password "$ADMIN_PASSWORD"

                        echo "✓ Admin password updated to clan vars successfully"
                        touch /var/lib/keycloak-password-sync/.sync-complete
                        exit 0
                      fi

                      # Try previous working password from state if available
                      if [ -f /var/lib/keycloak-password-sync/.last-password ]; then
                        LAST_PASSWORD=$(cat /var/lib/keycloak-password-sync/.last-password 2>/dev/null || true)
                        if [ -n "$LAST_PASSWORD" ] && [ "$LAST_PASSWORD" != "$ADMIN_PASSWORD" ]; then
                          echo "Trying previous working password..."
                          if ${pkgs.keycloak}/bin/kcadm.sh config credentials \
                            --server http://localhost:8080 \
                            --realm master \
                            --user admin \
                            --password "$LAST_PASSWORD" 2>/dev/null; then

                            echo "✓ Connected with previous password, updating to clan vars..."
                            ${pkgs.keycloak}/bin/kcadm.sh set-password \
                              --server http://localhost:8080 \
                              --realm master \
                              --target-realm master \
                              --username admin \
                              --new-password "$ADMIN_PASSWORD"

                            echo "✓ Admin password updated to clan vars successfully"
                            echo "$ADMIN_PASSWORD" > /var/lib/keycloak-password-sync/.last-password
                            touch /var/lib/keycloak-password-sync/.sync-complete
                            exit 0
                          fi
                        fi
                      fi

                      echo "⚠ Could not connect with bootstrap or previous passwords"
                      echo "Manual intervention required to reset admin password"
                      echo "Current clan vars password: $ADMIN_PASSWORD"
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
