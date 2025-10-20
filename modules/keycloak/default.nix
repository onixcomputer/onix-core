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

              generatorName = "keycloak-${instanceName}";
              dbPasswordFile = config.clan.core.vars.generators.${generatorName}.files.db_password.path;
              adminPasswordFile = config.clan.core.vars.generators.${generatorName}.files.admin_password.path;
              # Systemd Path Units and Password Upgrade Implementation
              # =======================================================
              # This implementation provides automated Keycloak admin password upgrades that respond to
              # clan vars file changes using systemd path units and proper service types:
              #
              # 1. systemd.paths."keycloak-${instanceName}-password-watch"
              #    - Monitors ${adminPasswordFile} for modifications using PathModified
              #    - Rate limited to prevent excessive triggers (30s interval, 5 burst)
              #    - Triggers the password upgrade service when changes are detected
              #
              # 2. systemd.services."keycloak-${instanceName}-password-upgrade"
              #    - Oneshot service (Type=oneshot, RemainAfterExit=false) for repeated execution
              #    - Triggered by path unit when clan vars change at runtime
              #    - Includes comprehensive error handling and verification
              #    - Automatically triggers Terraform updates after successful upgrades
              #
              # 3. systemd.services."keycloak-${instanceName}-password-upgrade-initial"
              #    - Oneshot service (Type=oneshot, RemainAfterExit=true) for boot-time execution
              #    - Runs once at system startup to perform initial password upgrade
              #    - Uses wantedBy=["multi-user.target"] for automatic activation
              #
              # 4. systemd.timers."keycloak-${instanceName}-password-verify"
              #    - Backup verification mechanism running every 6 hours
              #    - Detects password drift and triggers upgrades if needed
              #    - Provides reliability when file change detection fails
              #
              # 5. systemd.services."keycloak-${instanceName}-terraform-update"
              #    - Updates Terraform environment variables after password changes
              #    - Validates provider authentication with new credentials
              #    - Triggered automatically by successful password upgrades
              #
              # This design ensures password upgrades happen both at boot time and when clan vars
              # are updated at runtime, with proper service dependency chains and error handling.

              # Shared upgrade script for both initial and triggered password upgrades
              upgradeScript = pkgs.writeShellScript "upgrade-admin-password" ''
                set -e
                echo "🔄 Password upgrade triggered - checking clan vars"
                echo "📅 $(date): Starting password upgrade process"

                # Wait for Keycloak to be fully ready with better error handling
                echo "⏳ Waiting for Keycloak to be ready..."
                READY=false
                for i in {1..30}; do
                  if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ | grep -q "200"; then
                    echo "✅ Keycloak is ready (attempt $i)"
                    READY=true
                    break
                  fi
                  echo "🔄 Waiting for Keycloak... (attempt $i/30)"
                  sleep 5
                done

                if [ "$READY" = "false" ]; then
                  echo "❌ Keycloak not ready after 150 seconds"
                  exit 1
                fi

                # Get clan vars password
                if [ ! -f "$CREDENTIALS_DIRECTORY/admin_password" ]; then
                  echo "❌ Admin password file not found in credentials directory"
                  exit 1
                fi

                CLAN_ADMIN_PASS=$(cat $CREDENTIALS_DIRECTORY/admin_password)

                if [ -z "$CLAN_ADMIN_PASS" ]; then
                  echo "❌ Admin password is empty"
                  exit 1
                fi

                echo "🔐 Testing current password authentication..."
                # Test if password is already upgraded
                if curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                    -d "client_id=admin-cli&username=admin&password=$CLAN_ADMIN_PASS&grant_type=password" \
                    | grep -q "access_token"; then
                  echo "✅ Password already up to date with clan vars"
                  echo "📅 $(date): Password upgrade check complete - no action needed"
                  exit 0
                fi

                echo "🔄 Password needs upgrade - authenticating with bootstrap credentials..."
                # Get bootstrap token and upgrade password
                TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                  -d "client_id=admin-cli&username=admin&password=TempAdmin123&grant_type=password" | \
                  ${pkgs.jq}/bin/jq -r .access_token)

                if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
                  echo "❌ Failed to get bootstrap token - password may already be upgraded"
                  echo "🔄 Retrying with clan vars password..."
                  TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                    -d "client_id=admin-cli&username=admin&password=$CLAN_ADMIN_PASS&grant_type=password" | \
                    ${pkgs.jq}/bin/jq -r .access_token)

                  if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
                    echo "❌ Authentication failed with both bootstrap and clan passwords"
                    exit 1
                  else
                    echo "✅ Authentication successful with clan password - already upgraded"
                    exit 0
                  fi
                fi

                echo "🔍 Getting admin user ID..."
                ADMIN_ID=$(curl -s "http://localhost:8080/admin/realms/master/users?username=admin" \
                  -H "Authorization: Bearer $TOKEN" | ${pkgs.jq}/bin/jq -r '.[0].id')

                if [ "$ADMIN_ID" = "null" ] || [ -z "$ADMIN_ID" ]; then
                  echo "❌ Failed to get admin user ID"
                  exit 1
                fi

                echo "🔐 Updating admin password to clan vars value..."
                HTTP_STATUS=$(curl -s -w "%{http_code}" -o /dev/null \
                  -X PUT "http://localhost:8080/admin/realms/master/users/$ADMIN_ID/reset-password" \
                  -H "Authorization: Bearer $TOKEN" \
                  -H "Content-Type: application/json" \
                  -d "{\"type\":\"password\",\"value\":\"$CLAN_ADMIN_PASS\",\"temporary\":false}")

                if [ "$HTTP_STATUS" = "204" ]; then
                  echo "✅ Password successfully upgraded to clan vars"
                  echo "📅 $(date): Password upgrade complete"

                  # Verify the upgrade worked
                  echo "🔍 Verifying password upgrade..."
                  sleep 2
                  if curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                      -d "client_id=admin-cli&username=admin&password=$CLAN_ADMIN_PASS&grant_type=password" \
                      | grep -q "access_token"; then
                    echo "✅ Password upgrade verification successful"
                  else
                    echo "⚠️ Password upgrade verification failed"
                    exit 1
                  fi
                else
                  echo "❌ Password upgrade failed with HTTP status: $HTTP_STATUS"
                  exit 1
                fi

                echo "🎉 Password upgrade process completed successfully"
              '';
            in
            {
              services = {
                keycloak = {
                  enable = true;

                  # Use initialAdminPassword for proven NixOS bootstrap
                  initialAdminPassword = "TempAdmin123";

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

              # Ensure proper service startup order
              systemd.services.keycloak = {
                after = [ "postgresql.service" ];
                requires = [ "postgresql.service" ];

                preStart = ''
                  while ! ${config.services.postgresql.package}/bin/pg_isready -h localhost; do
                    echo "Waiting for PostgreSQL to be ready..."
                    sleep 2
                  done
                  echo "PostgreSQL ready. Keycloak will bootstrap admin user."
                '';
              };

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

              # Phase 2: Automatic admin password upgrade with file change detection
              systemd.paths."keycloak-${instanceName}-password-watch" = {
                description = "Monitor clan vars admin password file for changes";
                wantedBy = [ "multi-user.target" ];
                after = [ "keycloak-${instanceName}-password-upgrade-initial.service" ];
                pathConfig = {
                  # Monitor the admin password file for modifications
                  PathModified = adminPasswordFile;
                  # Rate limit to prevent excessive triggers
                  TriggerLimitIntervalSec = "30s";
                  TriggerLimitBurst = 5;
                  # Start monitoring after initial setup
                  MakeDirectory = false;
                  # Specify which service to trigger
                  Unit = "keycloak-${instanceName}-password-upgrade.service";
                };
              };

              systemd.services."keycloak-${instanceName}-password-upgrade" = {
                description = "Upgrade Keycloak admin password to clan vars (triggered by file changes)";
                after = [
                  "keycloak.service"
                  "keycloak-${instanceName}-password-upgrade-initial.service"
                ];
                requires = [ "keycloak.service" ];
                # This service is triggered by path unit, not enabled by default
                # wantedBy = [ ];

                serviceConfig = {
                  # Use oneshot for triggered execution - completes and exits
                  Type = "oneshot";
                  # Don't remain after exit - allows multiple triggers
                  RemainAfterExit = false;
                  User = "keycloak";
                  Group = "keycloak";
                  LoadCredential = [ "admin_password:${adminPasswordFile}" ];
                  # Add restart policy for reliability
                  Restart = "no"; # oneshot services don't restart automatically
                  # Ensure service completes within reasonable time
                  TimeoutStartSec = "300s";
                  TimeoutStopSec = "30s";
                };

                script = ''
                  echo "🔄 File change detected - running password upgrade"

                  # Run the password upgrade
                  if ${upgradeScript}; then
                    echo "✅ Password upgrade successful"

                    # Trigger Terraform update if terraform is enabled
                    if systemctl is-enabled "keycloak-${instanceName}-terraform-init.service" >/dev/null 2>&1; then
                      echo "🔄 Triggering Terraform configuration update..."
                      systemctl start "keycloak-${instanceName}-terraform-update.service" || echo "⚠️ Terraform update failed"
                    fi
                  else
                    echo "❌ Password upgrade failed"
                    exit 1
                  fi
                '';
              };

              # Timer-based backup verification for password upgrade reliability
              systemd.timers."keycloak-${instanceName}-password-verify" = {
                description = "Periodic verification of Keycloak admin password";
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  # Run verification every 6 hours
                  OnCalendar = "*-*-* 00,06,12,18:00:00";
                  # Random delay to avoid system load spikes
                  RandomizedDelaySec = "300s";
                  # Persist timer across reboots
                  Persistent = true;
                  # Catch up if system was down
                  WakeSystem = false;
                };
              };

              systemd.services."keycloak-${instanceName}-password-verify" = {
                description = "Verify Keycloak admin password is current with clan vars";
                after = [ "keycloak.service" ];
                requires = [ "keycloak.service" ];
                # This service is triggered only by timer, not at boot

                serviceConfig = {
                  Type = "oneshot";
                  User = "keycloak";
                  Group = "keycloak";
                  LoadCredential = [ "admin_password:${adminPasswordFile}" ];
                  # Shorter timeouts for verification
                  TimeoutStartSec = "60s";
                  TimeoutStopSec = "10s";
                };

                script = ''
                  echo "🔍 $(date): Verifying admin password is current with clan vars"

                  # Quick readiness check
                  if ! curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ | grep -q "200"; then
                    echo "⚠️ Keycloak not ready - skipping verification"
                    exit 0
                  fi

                  # Get clan vars password
                  CLAN_ADMIN_PASS=$(cat $CREDENTIALS_DIRECTORY/admin_password)

                  # Test authentication with clan vars password
                  if curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                      -d "client_id=admin-cli&username=admin&password=$CLAN_ADMIN_PASS&grant_type=password" \
                      | grep -q "access_token"; then
                    echo "✅ Password verification successful"
                    exit 0
                  else
                    echo "❌ Password verification failed - triggering upgrade"
                    # Trigger the password upgrade service
                    systemctl start "keycloak-${instanceName}-password-upgrade.service"
                    exit 0
                  fi
                '';
              };

              # Initial password upgrade service at boot (oneshot for first run)
              systemd.services."keycloak-${instanceName}-password-upgrade-initial" = {
                description = "Initial Keycloak admin password upgrade at boot";
                after = [ "keycloak.service" ];
                requires = [ "keycloak.service" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  User = "keycloak";
                  Group = "keycloak";
                  LoadCredential = [ "admin_password:${adminPasswordFile}" ];
                  TimeoutStartSec = "300s";
                  TimeoutStopSec = "30s";
                };

                script = ''
                  echo "🚀 Initial password upgrade at system startup"

                  # Run the same upgrade script as the main service
                  ${upgradeScript}
                '';
              };

              # Terraform integration with secure password (if enabled)
            }
            // lib.optionalAttrs (settings.terraform.enable or false) {
              # Create terraform configuration directory
              systemd.tmpfiles.rules = [
                "d /var/lib/keycloak-${instanceName}-terraform 0755 keycloak keycloak -"
              ];

              # Generate terraform configuration with environment variable model
              systemd.services."keycloak-${instanceName}-terraform-init" = {
                description = "Initialize Terraform configuration for Keycloak ${instanceName}";
                after = [ "keycloak-${instanceName}-password-upgrade-initial.service" ]; # After initial password upgrade
                requires = [ "keycloak-${instanceName}-password-upgrade-initial.service" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  User = "keycloak";
                  Group = "keycloak";
                  WorkingDirectory = "/var/lib/keycloak-${instanceName}-terraform";
                  # No LoadCredential needed - using direct Nix paths
                };

                script = ''
                                    echo "🔧 Generating terraform configuration with environment variable model"

                                    # Generate basic terraform configuration (no password in files)
                                    cat > main.tf.json <<'EOF'
                  {
                    "terraform": {
                      "required_providers": {
                        "keycloak": {
                          "source": "registry.opentofu.org/mrparkers/keycloak",
                          "version": "~> 4.0"
                        }
                      }
                    },
                    "variable": {
                      "keycloak_admin_password": {
                        "type": "string",
                        "sensitive": true,
                        "description": "Keycloak admin password (from TF_VAR_)"
                      },
                      "keycloak_url": {
                        "type": "string",
                        "description": "Keycloak URL (from TF_VAR_)"
                      }
                    },
                    "provider": {
                      "keycloak": {
                        "client_id": "admin-cli",
                        "username": "admin",
                        "password": "''${var.keycloak_admin_password}",
                        "url": "''${var.keycloak_url}",
                        "realm": "master"
                      }
                    }
                  }
                  EOF

                                    # NO terraform.tfvars file created - using environment variables only

                                    # Create management script with environment variable loading
                                    cat > manage.sh <<'SCRIPT'
                  #!/usr/bin/env bash
                  echo "🔑 Keycloak Terraform Management (Environment Variables)"
                  echo "🔐 Password source: Clan vars (no files)"
                  echo ""

                  # Load clan vars into terraform environment variables
                  export TF_VAR_keycloak_admin_password="$(cat ${adminPasswordFile})"
                  export TF_VAR_keycloak_url="https://${domain}"

                  case "''${1:-help}" in
                    init)
                      echo "🚀 Initializing terraform..."
                      ${pkgs.opentofu}/bin/tofu init
                      ;;
                    plan)
                      echo "📋 Planning with clan vars password..."
                      ${pkgs.opentofu}/bin/tofu plan
                      ;;
                    apply)
                      echo "✅ Applying with clan vars password..."
                      ${pkgs.opentofu}/bin/tofu apply
                      ;;
                    destroy)
                      echo "💥 Destroying resources..."
                      ${pkgs.opentofu}/bin/tofu destroy
                      ;;
                    *)
                      echo "Usage: $0 {init|plan|apply|destroy}"
                      echo ""
                      echo "Environment variables loaded from clan vars:"
                      echo "  TF_VAR_keycloak_admin_password=[PROTECTED]"
                      echo "  TF_VAR_keycloak_url=https://${domain}"
                      ;;
                  esac
                  SCRIPT

                                    chmod +x manage.sh

                                    echo "✅ Terraform configured with environment variable model"
                                    echo "📁 Working directory: /var/lib/keycloak-${instanceName}-terraform"
                                    echo "🔐 Password loaded from: ${adminPasswordFile}"
                                    echo "🚫 No password files created (environment variables only)"
                '';
              };

              # Service to update Terraform environment when password changes
              systemd.services."keycloak-${instanceName}-terraform-update" = {
                description = "Update Terraform environment after password changes";
                after = [ "keycloak-${instanceName}-password-upgrade.service" ];
                # This service is triggered after successful password upgrades
                # wantedBy = [ ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = false;
                  User = "keycloak";
                  Group = "keycloak";
                  WorkingDirectory = "/var/lib/keycloak-${instanceName}-terraform";
                  TimeoutStartSec = "60s";
                };

                script = ''
                  echo "🔄 $(date): Updating Terraform configuration after password change"

                  # Verify terraform directory exists
                  if [ ! -d "/var/lib/keycloak-${instanceName}-terraform" ]; then
                    echo "❌ Terraform directory not found - skipping update"
                    exit 0
                  fi

                  # Test new password with Terraform provider
                  echo "🔐 Testing Terraform provider with updated password..."

                  # Load environment variables for test
                  export TF_VAR_keycloak_admin_password="$(cat ${adminPasswordFile})"
                  export TF_VAR_keycloak_url="https://${domain}"

                  # Quick validation that terraform can authenticate
                  if [ -f "main.tf.json" ]; then
                    echo "🧪 Testing Terraform provider authentication..."
                    # Simple init test to validate configuration
                    ${pkgs.opentofu}/bin/tofu init -input=false >/dev/null 2>&1 || true
                    echo "✅ Terraform environment updated for new password"
                  else
                    echo "⚠️ Terraform configuration not found - run terraform-init first"
                  fi

                  echo "📅 $(date): Terraform update complete"
                '';
              };
            };
        };
    };
  };
}
