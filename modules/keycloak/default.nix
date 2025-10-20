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

              # Generate terraform configuration with proper admin user password management
              systemd.services."keycloak-${instanceName}-terraform-init" = {
                description = "Initialize Terraform and configure admin password management for Keycloak ${instanceName}";
                after = [ "keycloak.service" ];
                requires = [ "keycloak.service" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  User = "keycloak";
                  Group = "keycloak";
                  WorkingDirectory = "/var/lib/keycloak-${instanceName}-terraform";
                  LoadCredential = [ "admin_password:${adminPasswordFile}" ];
                };

                script = ''
                  echo "🔧 Generating terraform configuration with proper admin user management"

                  # Get the current admin password from clan vars
                  ADMIN_PASSWORD=$(cat $CREDENTIALS_DIRECTORY/admin_password)

                  # Generate terraform configuration using proper data source + resource pattern
                  cat > main.tf.json <<EOF
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
                        "description": "Admin password from clan vars"
                      },
                      "keycloak_bootstrap_password": {
                        "type": "string",
                        "sensitive": true,
                        "description": "Bootstrap password for initial authentication",
                        "default": "TempAdmin123"
                      }
                    },
                    "provider": {
                      "keycloak": {
                        "alias": "bootstrap",
                        "client_id": "admin-cli",
                        "username": "admin",
                        "password": "\''${var.keycloak_bootstrap_password}",
                        "url": "https://${domain}",
                        "realm": "master"
                      },
                      "keycloak": {
                        "alias": "final",
                        "client_id": "admin-cli",
                        "username": "admin",
                        "password": "\''${var.keycloak_admin_password}",
                        "url": "https://${domain}",
                        "realm": "master"
                      }
                    },
                    "data": {
                      "keycloak_user": {
                        "admin_user": {
                          "provider": "keycloak.bootstrap",
                          "realm_id": "master",
                          "username": "admin"
                        }
                      }
                    },
                    "resource": {
                      "keycloak_user": {
                        "admin_password_update": {
                          "provider": "keycloak.bootstrap",
                          "realm_id": "master",
                          "username": "admin",
                          "email": "\''${data.keycloak_user.admin_user.email}",
                          "email_verified": "\''${data.keycloak_user.admin_user.email_verified}",
                          "first_name": "\''${data.keycloak_user.admin_user.first_name}",
                          "last_name": "\''${data.keycloak_user.admin_user.last_name}",
                          "enabled": true,
                          "initial_password": {
                            "value": "\''${var.keycloak_admin_password}",
                            "temporary": false
                          }
                        }
                      },
                      "keycloak_user": {
                        "admin_validation": {
                          "provider": "keycloak.final",
                          "realm_id": "master",
                          "username": "admin",
                          "email": "\''${keycloak_user.admin_password_update.email}",
                          "email_verified": "\''${keycloak_user.admin_password_update.email_verified}",
                          "first_name": "\''${keycloak_user.admin_password_update.first_name}",
                          "last_name": "\''${keycloak_user.admin_password_update.last_name}",
                          "enabled": true,
                          "depends_on": [
                            "keycloak_user.admin_password_update"
                          ]
                        }
                      }
                    },
                    "output": {
                      "admin_password_upgrade_status": {
                        "value": {
                          "admin_user_id": "\''${data.keycloak_user.admin_user.id}",
                          "password_updated": "\''${keycloak_user.admin_password_update.id}",
                          "validation_passed": "\''${keycloak_user.admin_validation.id}",
                          "timestamp": "\''${timestamp()}"
                        },
                        "description": "Admin password upgrade status and validation"
                      }
                    }
                  }
                  EOF

                  # Create terraform.tfvars with the current password
                  cat > terraform.tfvars <<EOF
                  keycloak_admin_password = "$ADMIN_PASSWORD"
                  EOF

                  echo "🚀 Initializing terraform..."
                  if ! ${pkgs.opentofu}/bin/tofu init; then
                    echo "❌ Terraform initialization failed"
                    exit 1
                  fi

                  echo "🔍 Planning terraform changes..."
                  if ! ${pkgs.opentofu}/bin/tofu plan -out=password-update.tfplan; then
                    echo "❌ Terraform planning failed"
                    exit 1
                  fi

                  echo "🔄 Applying terraform (admin password update)..."
                  if ${pkgs.opentofu}/bin/tofu apply password-update.tfplan; then
                    echo "✅ Admin password updated successfully with clan vars"
                  else
                    echo "❌ Terraform apply failed - checking if password already up to date"

                    # Test if the password is already correct
                    if curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                        -d "client_id=admin-cli&username=admin&password=$ADMIN_PASSWORD&grant_type=password" \
                        | grep -q "access_token"; then
                      echo "✅ Password is already up to date"
                    else
                      echo "❌ Password update failed and authentication doesn't work"
                      exit 1
                    fi
                  fi

                  # Create management script for manual terraform operations
                  cat > manage.sh <<'SCRIPT'
                  #!/usr/bin/env bash
                  echo "🔑 Keycloak Terraform Management - Admin Password Updates"
                  echo "🔐 Password source: Clan vars"
                  echo ""

                  # Load current clan vars password
                  ADMIN_PASSWORD=$(cat ${adminPasswordFile})

                  case "''${1:-help}" in
                    init)
                      echo "🚀 Initializing terraform..."
                      ${pkgs.opentofu}/bin/tofu init
                      ;;
                    plan)
                      echo "📋 Planning password update..."
                      cat > terraform.tfvars <<EOF
                  keycloak_admin_password = "$ADMIN_PASSWORD"
                  EOF
                      ${pkgs.opentofu}/bin/tofu plan
                      ;;
                    apply)
                      echo "✅ Applying password update..."
                      cat > terraform.tfvars <<EOF
                  keycloak_admin_password = "$ADMIN_PASSWORD"
                  EOF
                      ${pkgs.opentofu}/bin/tofu apply
                      ;;
                    destroy)
                      echo "💥 Destroying resources..."
                      ${pkgs.opentofu}/bin/tofu destroy
                      ;;
                    test)
                      echo "🧪 Testing current password authentication..."
                      if curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                          -d "client_id=admin-cli&username=admin&password=$ADMIN_PASSWORD&grant_type=password" \
                          | grep -q "access_token"; then
                        echo "✅ Authentication successful with clan vars password"
                      else
                        echo "❌ Authentication failed with clan vars password"
                      fi
                      ;;
                    *)
                      echo "Usage: $0 {init|plan|apply|destroy|test}"
                      echo ""
                      echo "Commands:"
                      echo "  init    - Initialize terraform"
                      echo "  plan    - Plan password update changes"
                      echo "  apply   - Apply password update"
                      echo "  destroy - Remove terraform resources"
                      echo "  test    - Test current password authentication"
                      echo ""
                      echo "Password loaded from: ${adminPasswordFile}"
                      ;;
                  esac
                  SCRIPT

                  chmod +x manage.sh

                  echo "✅ Terraform configured with proper admin password management"
                  echo "📁 Working directory: /var/lib/keycloak-${instanceName}-terraform"
                  echo "🔐 Password loaded from: ${adminPasswordFile}"
                  echo "🧪 Run './manage.sh test' to verify authentication"
                '';
              };

              # Service to update Terraform configuration when password changes
              systemd.services."keycloak-${instanceName}-terraform-update" = {
                description = "Update Terraform admin password after clan vars changes";
                after = [ "keycloak-${instanceName}-password-upgrade.service" ];
                # This service is triggered after successful password upgrades
                # wantedBy = [ ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = false;
                  User = "keycloak";
                  Group = "keycloak";
                  WorkingDirectory = "/var/lib/keycloak-${instanceName}-terraform";
                  LoadCredential = [ "admin_password:${adminPasswordFile}" ];
                  TimeoutStartSec = "120s";
                };

                script = ''
                  echo "🔄 $(date): Updating Terraform admin password after clan vars change"

                  # Verify terraform directory exists
                  if [ ! -d "/var/lib/keycloak-${instanceName}-terraform" ]; then
                    echo "❌ Terraform directory not found - skipping update"
                    exit 0
                  fi

                  # Verify terraform configuration exists
                  if [ ! -f "main.tf.json" ]; then
                    echo "❌ Terraform configuration not found - run terraform-init first"
                    exit 0
                  fi

                  # Get the current admin password from clan vars
                  ADMIN_PASSWORD=$(cat $CREDENTIALS_DIRECTORY/admin_password)

                  echo "🔐 Updating terraform.tfvars with new password..."
                  cat > terraform.tfvars <<EOF
                  keycloak_admin_password = "$ADMIN_PASSWORD"
                  EOF

                  echo "🧪 Testing authentication with new password..."
                  if curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                      -d "client_id=admin-cli&username=admin&password=$ADMIN_PASSWORD&grant_type=password" \
                      | grep -q "access_token"; then
                    echo "✅ Authentication successful with new password"
                  else
                    echo "❌ Authentication failed with new password - terraform update skipped"
                    exit 1
                  fi

                  echo "📋 Planning terraform password update..."
                  if ${pkgs.opentofu}/bin/tofu plan -out=password-update.tfplan; then
                    echo "🔄 Applying terraform password update..."
                    if ${pkgs.opentofu}/bin/tofu apply password-update.tfplan; then
                      echo "✅ Terraform admin password updated successfully"
                    else
                      echo "⚠️ Terraform apply failed, but password may already be current"
                    fi
                  else
                    echo "⚠️ Terraform planning failed, but password may already be current"
                  fi

                  echo "📅 $(date): Terraform password update complete"
                '';
              };
            };
        };
    };
  };
}
