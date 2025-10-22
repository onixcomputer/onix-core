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
              terraformGenerator = import ./terraform-generator.nix { inherit lib; };
              generateTerraformConfig = terraformGenerator.generateTerraformConfig;

              generatorName = "keycloak-${instanceName}";
              dbPasswordFile = config.clan.core.vars.generators.${generatorName}.files.db_password.path;
              adminPasswordFile = config.clan.core.vars.generators.${generatorName}.files.admin_password.path;
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

              # Basic service startup order
              systemd.services.keycloak = {
                after = [ "postgresql.service" ];
                requires = [ "postgresql.service" ];

                preStart = ''
                  while ! ${config.services.postgresql.package}/bin/pg_isready -h localhost; do
                    echo "Waiting for PostgreSQL to be ready..."
                    sleep 2
                  done
                  echo "PostgreSQL ready. Starting Keycloak."
                '';

                postStart = lib.mkIf terraformAutoApply (
                  lib.mkAfter ''
                    # Trigger terraform configuration non-blocking
                    ${pkgs.systemd}/bin/systemctl start --no-block keycloak-terraform-${instanceName}.service || true
                  ''
                );
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

              # Garage bucket setup for Terraform state (if using S3 backend)
              systemd.services."garage-terraform-init-${instanceName}" =
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

              # Automated OpenTofu execution
              systemd.services."keycloak-terraform-${instanceName}" =
                lib.mkIf (terraformAutoApply && (settings.terraform.enable or false))
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
                    partOf = [ "keycloak.service" ];

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
                      rm -f simple-main.tf.json *.tf.json.backup 2>/dev/null || true

                      # Generate Terraform configuration
                      echo "Generating Terraform configuration for ${instanceName}..."
                      echo "Settings.terraform.enable: ${if settings.terraform.enable or false then "true" else "false"}"
                      cat > main.tf.json <<'EOF'
                      ${(generateTerraformConfig instanceName settings adminPasswordFile).terraformJson}
                      EOF
                      echo "Generated main.tf.json ($(wc -c < main.tf.json) bytes)"

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

                      echo "OpenTofu completed successfully"
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
              ];
            };
        };
    };
  };
}
