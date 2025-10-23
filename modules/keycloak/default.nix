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

              # OpenTofu library functions
              opentofu = import ../lib/opentofu/default.nix { inherit lib pkgs; };

              # Enhanced terranix integration
              terranix = import ../lib/opentofu/terranix.nix { inherit lib pkgs; };

              # Define credential mapping for OpenTofu library
              credentialMapping = { };

              # Dependencies for terraform deployment
              deploymentDependencies = [
                "keycloak.service"
                "keycloak-admin-password-reset.service"
              ]
              ++ lib.optionals (terraformBackend == "s3") [ "garage-terraform-init-${instanceName}.service" ];
            in
            {
              services = {
                keycloak = {
                  enable = true;

                  # Use bootstrap password (will be updated by terraform to clan vars)
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
                (terranix.mkTerranixDeploymentService {
                  serviceName = "keycloak";
                  inherit instanceName;

                  # Use the new terranix module
                  terranixModule = ./terranix-config.nix;
                  moduleArgs = {
                    inherit lib settings;
                  };

                  inherit credentialMapping;
                  dependencies = deploymentDependencies;
                  backendType = terraformBackend;
                  timeoutSec = "10m";

                  # Enhanced terranix options
                  validateConfig = true;
                  debugMode = false;
                  prettyPrintJson = false;

                  preTerraformScript = "echo 'No terraform variables needed - using hardcoded bootstrap password'";
                })
                // (lib.optionalAttrs (terraformBackend == "s3") (
                  opentofu.mkGarageInitService {
                    serviceName = "keycloak";
                    inherit instanceName;
                  }
                ))
                // {
                  # Admin password reset service to ensure bootstrap password is active
                  "keycloak-admin-password-reset" = {
                    description = "Reset Keycloak admin password to bootstrap password";
                    after = [ "keycloak.service" ];
                    requires = [ "keycloak.service" ];
                    wantedBy = [ "multi-user.target" ];

                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      StateDirectory = "keycloak-admin-reset";
                      WorkingDirectory = "/var/lib/keycloak-admin-reset";
                    };

                    path = with pkgs; [
                      keycloak
                      curl
                      jq
                    ];

                    script = ''
                      set -euo pipefail

                      echo "Resetting Keycloak admin password to bootstrap password..."

                      # Wait for Keycloak to be ready
                      for i in {1..30}; do
                        if curl -sf http://localhost:8080/realms/master >/dev/null 2>&1; then
                          break
                        fi
                        echo "Waiting for Keycloak... (attempt $i/30)"
                        sleep 2
                      done

                      # Use Keycloak admin CLI to reset admin password
                      export JAVA_HOME="${pkgs.openjdk_headless}"

                      # Try multiple possible passwords to find the current one
                      PASSWORDS=("TemporaryBootstrapPassword123!" "GQLpLkcUdE7Xs3cxzO6hyAruz9l7rsOy" "admin")

                      for CURRENT_PASSWORD in "''${PASSWORDS[@]}"; do
                        echo "Trying password reset with current password: [REDACTED]"
                        if ${pkgs.keycloak}/bin/kcadm.sh config credentials \
                          --server http://localhost:8080 \
                          --realm master \
                          --user admin \
                          --password "$CURRENT_PASSWORD" 2>/dev/null; then

                          echo "✓ Connected successfully, updating admin password"

                          # Reset admin password to bootstrap password
                          ${pkgs.keycloak}/bin/kcadm.sh set-password \
                            --server http://localhost:8080 \
                            --realm master \
                            --target-realm master \
                            --username admin \
                            --new-password TemporaryBootstrapPassword123!

                          echo "✓ Admin password reset completed successfully"
                          touch /var/lib/keycloak-admin-reset/.reset-complete
                          exit 0
                        fi
                      done

                      echo "⚠ Could not connect with any known password - manual intervention required"
                      touch /var/lib/keycloak-admin-reset/.password-mismatch
                      exit 0  # Don't fail the service
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

                    # Note: terraform auto-application is now handled by a systemd timer
                    # that periodically checks for .needs-apply flag
                  };

                  # Garage bucket setup for Terraform state (if using S3 backend)
                  "garage-terraform-init-${instanceName}" =
                    lib.mkIf (terraformBackend == "s3" && terraformAutoApply)
                      {
                        description = "Initialize Garage bucket for Keycloak Terraform";
                        after = [ "garage.service" ];
                        requires = [ "garage.service" ];
                        before = [ "keycloak-terraform-deploy-${instanceName}.service" ];
                        wantedBy = [ "multi-user.target" ];

                        path = [
                          pkgs.garage
                          pkgs.curl
                          pkgs.jq
                          pkgs.gawk
                          pkgs.gnugrep
                        ];

                        serviceConfig = {
                          Type = "oneshot";
                          RemainAfterExit = true;
                          StateDirectory = "garage-terraform-${instanceName}";
                          WorkingDirectory = "/var/lib/garage-terraform-${instanceName}";

                          LoadCredential =
                            lib.optionals (config.clan.core.vars.generators ? "garage") [
                              "admin_token:${config.clan.core.vars.generators.garage.files.admin_token.path}"
                            ]
                            ++ lib.optionals (config.clan.core.vars.generators ? "garage-shared") [
                              "rpc_secret:${config.clan.core.vars.generators.garage-shared.files.rpc_secret.path}"
                            ];
                        };

                        script = ''
                          set -euo pipefail

                          # Wait for Garage to be ready
                          echo "Waiting for Garage API..."
                          for i in {1..30}; do
                            if curl -sf http://127.0.0.1:3903/health 2>/dev/null; then
                              break
                            fi
                            sleep 2
                          done

                          if [ -f "$CREDENTIALS_DIRECTORY/admin_token" ]; then
                            export GARAGE_ADMIN_TOKEN=$(cat $CREDENTIALS_DIRECTORY/admin_token)
                          fi

                          if [ -f "$CREDENTIALS_DIRECTORY/rpc_secret" ]; then
                            export GARAGE_RPC_SECRET=$(cat $CREDENTIALS_DIRECTORY/rpc_secret)
                          fi

                          GARAGE="${pkgs.garage}/bin/garage"

                          # Create bucket if doesn't exist
                          if ! $GARAGE bucket info terraform-state 2>/dev/null; then
                            echo "Creating terraform-state bucket..."
                            $GARAGE bucket create terraform-state
                          fi

                          # Create access key if doesn't exist
                          KEY_NAME="keycloak-${instanceName}-tf"
                          if ! $GARAGE key info $KEY_NAME 2>/dev/null; then
                            echo "Creating access key..."
                            $GARAGE key create $KEY_NAME

                            # Grant permissions
                            $GARAGE bucket allow terraform-state --read --write --owner --key $KEY_NAME
                          fi

                          # Get credentials - parse text output
                          KEY_ID=$($GARAGE key info $KEY_NAME | grep -E '^Key ID:' | awk '{print $3}')
                          SECRET=$($GARAGE key info $KEY_NAME --show-secret | grep -E '^Secret key:' | awk '{print $3}')

                          # Save credentials
                          echo "$KEY_ID" > access_key_id
                          echo "$SECRET" > secret_access_key

                          echo "Garage bucket and credentials ready"
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
