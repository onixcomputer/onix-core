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
              terraformAutoApply = settings.terraformAutoApply or false;
              terraformLockTimeout = settings.terraformLockTimeout or 300; # Default 5 minutes
              # Use terranix for terraform configuration generation

              generatorName = "keycloak-${instanceName}";
              dbPasswordFile = config.clan.core.vars.generators.${generatorName}.files.db_password.path;
              adminPasswordFile = config.clan.core.vars.generators.${generatorName}.files.admin_password.path;

              # Generate Terraform configuration at build time
              terraformConfigJson = pkgs.writeText "keycloak-terraform-${instanceName}.json" (
                builtins.toJSON (
                  import ./terranix-config.nix {
                    inherit (pkgs) lib;
                    inherit settings;
                  }
                )
              );
            in
            {
              services = {
                keycloak = {
                  enable = true;

                  # Use clan vars password file for admin password
                  # Temporarily hardcoded to match clan vars for terraform bootstrap
                  initialAdminPassword = lib.mkForce "NewTestPass456";

                  settings = {
                    hostname = domain;
                    proxy-headers = "xforwarded";
                    http-enabled = true;
                    http-port = 8080;
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

              # Combined systemd services
              systemd.services = {
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
                      before = [ "keycloak-terraform-${instanceName}.service" ];
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

                # Legacy terraform service - now disabled, replaced by keycloak-terraform-deploy service
                "keycloak-terraform-${instanceName}" =
                  lib.mkIf (false && terraformAutoApply && (settings.terraform.enable or false))
                    {
                      description = "Apply Keycloak Terraform configuration";

                      after = [
                        "keycloak.service"
                      ]
                      ++ lib.optionals (terraformBackend == "s3") [ "garage-terraform-init-${instanceName}.service" ];
                      requires = [
                        "keycloak.service"
                      ]
                      ++ lib.optionals (terraformBackend == "s3") [ "garage-terraform-init-${instanceName}.service" ];

                      # Do not auto-start - only run when triggered by timer or manually
                      # wantedBy = [ "keycloak.service" ];
                      # bindsTo = [ "keycloak.service" ];
                      # partOf = [ "keycloak.service" ];

                      path = [
                        pkgs.opentofu
                        pkgs.curl
                        pkgs.jq
                        pkgs.coreutils
                      ];

                      serviceConfig = {
                        Type = "oneshot";
                        RemainAfterExit = false;

                        StateDirectory = "keycloak-${instanceName}-terraform";
                        WorkingDirectory = "/var/lib/keycloak-${instanceName}-terraform";

                        TimeoutStartSec = "20m";
                        Restart = "on-failure";
                        RestartSec = "30s";

                        LoadCredential = [
                          "admin_password:${adminPasswordFile}"
                        ];
                      };

                      script = ''
                                              set -euo pipefail

                                              echo "Starting OpenTofu for Keycloak ${instanceName}"

                                              # Check if activation script detected changes that need to be applied
                                              if [ ! -f "$STATE_DIRECTORY/.needs-apply" ]; then
                                                echo "No terraform changes detected by activation script"
                                                echo "Use 'systemctl start keycloak-terraform-${instanceName}.service' to force execution"
                                                exit 0
                                              fi

                                              echo "Activation script detected configuration changes - proceeding with terraform apply"

                                              # State locking implementation
                                              LOCK_FILE="$STATE_DIRECTORY/.terraform.lock"
                                              LOCK_TIMEOUT=${toString terraformLockTimeout}

                                              echo "Acquiring terraform state lock..."

                                              # Try to acquire exclusive lock with timeout
                                              exec 200>"$LOCK_FILE"
                                              if ! ${pkgs.util-linux}/bin/flock -w $LOCK_TIMEOUT -x 200; then
                                                echo "ERROR: Failed to acquire terraform lock after $LOCK_TIMEOUT seconds"
                                                echo "Another terraform operation may be in progress"
                                                echo "Lock file: $LOCK_FILE"

                                                # Check if lock info file exists and show details
                                                if [ -f "$LOCK_FILE.info" ]; then
                                                  echo "Lock held by:"
                                                  cat "$LOCK_FILE.info"
                                                fi

                                                echo "To force unlock: systemctl stop keycloak-terraform-${instanceName} && rm -f $LOCK_FILE $LOCK_FILE.info"
                                                exit 1
                                              fi

                                              # Lock acquired - record lock info
                                              echo "Lock acquired by PID $$"
                                              cat > "$LOCK_FILE.info" <<EOF
                        PID: $$
                        Date: $(date -Iseconds)
                        Service: keycloak-terraform-${instanceName}
                        User: $(whoami)
                        EOF

                                              # Ensure lock is released on exit
                                              trap "rm -f '$LOCK_FILE.info'; exec 200>&-" EXIT INT TERM

                                              # Wait for Keycloak (check for 302 redirect which indicates it's running)
                                              echo "Waiting for Keycloak..."
                                              for i in {1..60}; do
                                                HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ 2>/dev/null || echo "000")
                                                if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
                                                  echo "Keycloak is ready (HTTP $HTTP_CODE)"
                                                  break
                                                fi
                                                [ $i -eq 60 ] && { echo "Timeout waiting for Keycloak"; exit 1; }
                                                echo "Waiting... (attempt $i/60, got HTTP $HTTP_CODE)"
                                                sleep 5
                                              done

                                              # Load Garage credentials for S3-compatible state backend
                                              ${
                                                if terraformBackend == "s3" then
                                                  ''
                                                                                # Load Garage credentials
                                                                                if [ -f "/var/lib/garage-terraform-${instanceName}/access_key_id" ]; then
                                                                                  export AWS_ACCESS_KEY_ID=$(cat /var/lib/garage-terraform-${instanceName}/access_key_id)
                                                                                  export AWS_SECRET_ACCESS_KEY=$(cat /var/lib/garage-terraform-${instanceName}/secret_access_key)
                                                                                  echo "Loaded Garage credentials for state backend"
                                                                                else
                                                                                  echo "ERROR: Garage credentials not found at /var/lib/garage-terraform-${instanceName}/"
                                                                                  exit 1
                                                                                fi

                                                                                # Generate S3 backend configuration
                                                                                cat > backend.tf <<'EOF'
                                                    terraform {
                                                      backend "s3" {
                                                        endpoint = "http://127.0.0.1:3900"
                                                        bucket = "terraform-state"
                                                        key = "keycloak/${instanceName}/terraform.tfstate"
                                                        region = "garage"

                                                        skip_credentials_validation = true
                                                        skip_metadata_api_check = true
                                                        skip_region_validation = true
                                                        force_path_style = true
                                                      }
                                                    }
                                                    EOF
                                                  ''
                                                else
                                                  ''
                                                                                # Local backend
                                                                                cat > backend.tf <<'EOF'
                                                    terraform {
                                                      backend "local" {
                                                        path = "terraform.tfstate"
                                                      }
                                                    }
                                                    EOF
                                                  ''
                                              }

                                              # Clean up any old terraform files to prevent conflicts
                                              echo "Cleaning up old terraform files..."
                                              rm -f simple-main.tf.json *.tf.json.backup main.tf.json 2>/dev/null || true

                                              # Copy pre-generated Terraform configuration
                                              echo "Using Terraform configuration for ${instanceName}..."
                                              cp ${terraformConfigJson} ./main.tf.json
                                              echo "Loaded main.tf.json ($(wc -c < main.tf.json) bytes)"

                                              # Generate tfvars with hardcoded password
                                              cat > terraform.tfvars <<EOF
                        keycloak_admin_password = "NewTestPass456"
                        EOF

                                              # Initialize Terraform (always reconfigure for S3 backend to handle changes)
                                              ${lib.optionalString (settings.terraformBackend == "s3") ''
                                                echo "Initializing Terraform with S3 backend..."
                                                tofu init -reconfigure -upgrade -input=false
                                              ''}
                                              ${lib.optionalString (settings.terraformBackend != "s3") ''
                                                if [ ! -d .terraform ]; then
                                                  echo "Initializing Terraform..."
                                                  tofu init -upgrade -input=false
                                                fi
                                              ''}

                                              # Check configuration hash for idempotency
                                              CONFIG_HASH=$(sha256sum main.tf.json terraform.tfvars 2>/dev/null | sha256sum | cut -d' ' -f1)
                                              LAST_HASH=""

                                              if [ -f .last-config-hash ]; then
                                                LAST_HASH=$(cat .last-config-hash)
                                              fi

                                              if [ "$CONFIG_HASH" = "$LAST_HASH" ]; then
                                                echo "Configuration unchanged - checking drift..."
                                              fi

                                              # Plan
                                              echo "Planning changes..."
                                              set +e
                                              tofu plan -var-file=terraform.tfvars -detailed-exitcode -out=tfplan
                                              PLAN_EXIT=$?
                                              set -e

                                              case $PLAN_EXIT in
                                                0)
                                                  echo "No changes needed"
                                                  echo "$CONFIG_HASH" > .last-config-hash
                                                  exit 0
                                                  ;;
                                                1)
                                                  echo "Plan failed"
                                                  exit 1
                                                  ;;
                                                2)
                                                  echo "Changes detected - applying..."
                                                  ;;
                                              esac

                                              # Apply
                                              echo "Applying configuration..."
                                              tofu apply -auto-approve tfplan
                                              echo "$CONFIG_HASH" > .last-config-hash

                                              # Remove the needs-apply flag to indicate successful completion
                                              rm -f "$STATE_DIRECTORY/.needs-apply"

                                              echo "OpenTofu completed successfully"
                      '';
                    };

              };

              # Simple activation script to reset deploy flag when configuration changes
              system.activationScripts."keycloak-terraform-reset-${instanceName}" = lib.mkIf terraformAutoApply {
                text = ''
                  # Create state directory if it doesn't exist
                  mkdir -p /var/lib/keycloak-${instanceName}-terraform

                  # Check if terraform configuration has changed
                  CURRENT_CONFIG_HASH=$(sha256sum ${terraformConfigJson} | cut -d' ' -f1)
                  LAST_DEPLOY_HASH=$(cat /var/lib/keycloak-${instanceName}-terraform/.last-deploy-hash 2>/dev/null || echo "")

                  if [ "$CURRENT_CONFIG_HASH" != "$LAST_DEPLOY_HASH" ]; then
                    echo "Terraform configuration changed - clearing deploy flag"
                    rm -f /var/lib/keycloak-${instanceName}-terraform/.deploy-complete
                  fi
                '';
                deps = [ "setupSecrets" ];
              };

              # Oneshot service for synchronous terraform execution during deployment
              systemd.services."keycloak-terraform-deploy-${instanceName}" = lib.mkIf terraformAutoApply {
                description = "Deploy Keycloak terraform configuration synchronously";

                # Run after all dependencies are ready
                after = [
                  "keycloak.service"
                ]
                ++ lib.optionals (terraformBackend == "s3") [ "garage-terraform-init-${instanceName}.service" ];

                requires = [
                  "keycloak.service"
                ]
                ++ lib.optionals (terraformBackend == "s3") [ "garage-terraform-init-${instanceName}.service" ];

                # Make this part of the deployment transaction
                wantedBy = [ "multi-user.target" ];

                # Ensure it only runs once per configuration change
                unitConfig = {
                  ConditionPathExists = "!/var/lib/keycloak-${instanceName}-terraform/.deploy-complete";
                };

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  StateDirectory = "keycloak-${instanceName}-terraform";
                  WorkingDirectory = "/var/lib/keycloak-${instanceName}-terraform";
                  TimeoutStartSec = "10m";
                  LoadCredential = [
                    "admin_password:${adminPasswordFile}"
                  ];
                };

                path = [
                  pkgs.opentofu
                  pkgs.curl
                  pkgs.jq
                  pkgs.coreutils
                ];

                script = ''
                  echo "Checking for Keycloak terraform configuration changes during deployment..."

                  # Generate current terraform configuration hash from the build-time config
                  CURRENT_CONFIG_HASH=$(sha256sum ${terraformConfigJson} | cut -d' ' -f1)
                  LAST_APPLIED_HASH=$(cat .last-deploy-hash 2>/dev/null || echo "")

                  if [ "$CURRENT_CONFIG_HASH" != "$LAST_APPLIED_HASH" ]; then
                    echo "Terraform configuration changed - applying during deployment..."

                    # Copy the new configuration
                    cp ${terraformConfigJson} ./main.tf.json

                    # Generate tfvars
                    cat > terraform.tfvars <<EOF
                  keycloak_admin_password = "NewTestPass456"
                  EOF

                    # Wait for Keycloak to be ready
                    echo "Waiting for Keycloak to be ready..."
                    for i in {1..60}; do
                      HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ 2>/dev/null || echo "000")
                      if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
                        echo "Keycloak is ready (HTTP $HTTP_CODE)"
                        break
                      fi
                      [ $i -eq 60 ] && { echo "ERROR: Keycloak not ready for terraform deployment"; exit 1; }
                      echo "Waiting for Keycloak... (attempt $i/60)"
                      sleep 2
                    done

                    # Load backend credentials
                    ${
                      if terraformBackend == "s3" then
                        ''
                          export AWS_ACCESS_KEY_ID=$(cat /var/lib/garage-terraform-${instanceName}/access_key_id)
                          export AWS_SECRET_ACCESS_KEY=$(cat /var/lib/garage-terraform-${instanceName}/secret_access_key)
                          echo "Loaded Garage credentials"

                          cat > backend.tf <<'EOF'
                          terraform {
                            backend "s3" {
                              endpoint = "http://127.0.0.1:3900"
                              bucket = "terraform-state"
                              key = "keycloak/${instanceName}/terraform.tfstate"
                              region = "garage"
                              skip_credentials_validation = true
                              skip_metadata_api_check = true
                              skip_region_validation = true
                              force_path_style = true
                            }
                          }
                          EOF
                        ''
                      else
                        ''
                          cat > backend.tf <<'EOF'
                          terraform {
                            backend "local" {
                              path = "terraform.tfstate"
                            }
                          }
                          EOF
                        ''
                    }

                    # Execute terraform
                    echo "Executing terraform during deployment..."
                    ${pkgs.opentofu}/bin/tofu init -upgrade -input=false

                    set +e
                    ${pkgs.opentofu}/bin/tofu plan -var-file=terraform.tfvars -detailed-exitcode -out=tfplan
                    PLAN_EXIT=$?
                    set -e

                    case $PLAN_EXIT in
                      0)
                        echo "No terraform changes needed"
                        ;;
                      1)
                        echo "ERROR: Terraform plan failed during deployment"
                        exit 1
                        ;;
                      2)
                        echo "Applying terraform changes during deployment..."
                        ${pkgs.opentofu}/bin/tofu apply -auto-approve tfplan
                        echo "Terraform applied successfully during deployment"
                        ;;
                    esac

                    # Mark deployment complete
                    echo "$CURRENT_CONFIG_HASH" > .last-deploy-hash
                    touch .deploy-complete
                    echo "Terraform deployment completed"
                  else
                    echo "Terraform configuration unchanged"
                    touch .deploy-complete
                  fi
                '';
              };

              # Helper commands for terraform lock management
              environment.systemPackages = with pkgs; [
                (writeScriptBin "keycloak-tf-unlock-${instanceName}" ''
                  #!${pkgs.bash}/bin/bash
                  LOCK_FILE="/var/lib/keycloak-${instanceName}-terraform/.terraform.lock"
                  LOCK_INFO="/var/lib/keycloak-${instanceName}-terraform/.terraform.lock.info"

                  if [ ! -f "$LOCK_FILE" ] && [ ! -f "$LOCK_INFO" ]; then
                    echo "No lock files found"
                    exit 0
                  fi

                  echo "Current lock status:"
                  if [ -f "$LOCK_INFO" ]; then
                    cat "$LOCK_INFO"
                  fi

                  read -p "Force unlock terraform state? (y/N) " -n 1 -r
                  echo
                  if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm -f "$LOCK_FILE" "$LOCK_INFO"
                    echo "Lock removed"
                  else
                    echo "Cancelled"
                  fi
                '')

                (writeScriptBin "keycloak-tf-status-${instanceName}" ''
                  #!${pkgs.bash}/bin/bash
                  LOCK_FILE="/var/lib/keycloak-${instanceName}-terraform/.terraform.lock"
                  LOCK_INFO="/var/lib/keycloak-${instanceName}-terraform/.terraform.lock.info"

                  echo "=== Terraform Lock Status for ${instanceName} ==="
                  if [ -f "$LOCK_FILE" ] || [ -f "$LOCK_INFO" ]; then
                    echo "Lock is ACTIVE"
                    if [ -f "$LOCK_INFO" ]; then
                      echo "Lock details:"
                      cat "$LOCK_INFO"
                    fi

                    # Check if the PID is still running
                    if [ -f "$LOCK_INFO" ]; then
                      PID=$(grep "^PID:" "$LOCK_INFO" | awk '{print $2}')
                      if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
                        echo "Process $PID is still running"
                      else
                        echo "WARNING: Process $PID is not running (lock may be stale)"
                      fi
                    fi
                  else
                    echo "No active lock"
                  fi

                  echo ""
                  echo "=== Terraform Service Status ==="
                  systemctl status --no-pager -l keycloak-terraform-${instanceName}.service || true
                '')

                (writeScriptBin "keycloak-tf-apply-${instanceName}" ''
                  #!${pkgs.bash}/bin/bash
                  echo "Triggering terraform apply for ${instanceName}..."
                  systemctl start keycloak-terraform-${instanceName}.service

                  # Follow the logs
                  journalctl -u keycloak-terraform-${instanceName}.service -f
                '')

                (writeScriptBin "keycloak-tf-watch-${instanceName}" ''
                  #!${pkgs.bash}/bin/bash
                  echo "Manually triggering terraform watcher for ${instanceName}..."

                  # Show current status
                  echo "=== Current Status ==="
                  echo "Keycloak service: $(systemctl is-active keycloak.service)"
                  echo "Terraform service: $(systemctl is-active keycloak-terraform-${instanceName}.service)"
                  echo "Watcher timer: $(systemctl is-active keycloak-terraform-watcher-${instanceName}.timer)"

                  # Check for .needs-apply flag
                  if [ -f "/var/lib/keycloak-${instanceName}-terraform/.needs-apply" ]; then
                    echo ".needs-apply flag: EXISTS"
                  else
                    echo ".needs-apply flag: NOT FOUND"
                  fi

                  echo ""
                  echo "Triggering watcher service manually..."
                  systemctl start keycloak-terraform-watcher-${instanceName}.service

                  # Follow the logs
                  journalctl -u keycloak-terraform-watcher-${instanceName}.service -f
                '')
              ];
            };
        };
    };
  };
}
