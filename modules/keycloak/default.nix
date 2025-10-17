{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption;
  inherit (lib.types) str attrsOf anything bool listOf submodule;
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

              # Phase 2: Automatic admin password upgrade to clan vars
              systemd.services."keycloak-${instanceName}-password-upgrade" = {
                description = "Upgrade Keycloak admin password to clan vars";
                after = [ "keycloak.service" ];
                requires = [ "keycloak.service" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  User = "keycloak";
                  Group = "keycloak";
                  LoadCredential = [ "admin_password:${adminPasswordFile}" ];
                };

                script = let
                  upgradeScript = pkgs.writeShellScript "upgrade-admin-password" ''
                    set -e

                    echo "🔄 Phase 2: Upgrading admin password to clan vars"

                    # Wait for Keycloak to be fully ready
                    echo "Waiting for Keycloak to be ready..."
                    for i in {1..30}; do
                      if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ | grep -q "200"; then
                        echo "✅ Keycloak is ready"
                        break
                      fi
                      echo "Attempt $i/30: Keycloak not ready yet..."
                      sleep 5
                    done

                    # Get clan vars password
                    CLAN_ADMIN_PASS=$(cat $CREDENTIALS_DIRECTORY/admin_password)
                    echo "🔐 Using clan vars password for upgrade"

                    # Test if password is already upgraded
                    if curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                        -d "client_id=admin-cli&username=admin&password=$CLAN_ADMIN_PASS&grant_type=password" \
                        | grep -q "access_token"; then
                      echo "✅ Password already upgraded to clan vars - skipping"
                      exit 0
                    fi

                    echo "🔑 Getting bootstrap admin token..."
                    TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                      -d "client_id=admin-cli&username=admin&password=TempAdmin123&grant_type=password" | \
                      ${pkgs.jq}/bin/jq -r .access_token)

                    if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
                      echo "❌ Failed to get bootstrap admin token"
                      exit 1
                    fi

                    echo "✅ Got bootstrap token"

                    echo "🔍 Getting admin user ID..."
                    ADMIN_ID=$(curl -s "http://localhost:8080/admin/realms/master/users?username=admin" \
                      -H "Authorization: Bearer $TOKEN" | ${pkgs.jq}/bin/jq -r '.[0].id')

                    if [ "$ADMIN_ID" = "null" ] || [ -z "$ADMIN_ID" ]; then
                      echo "❌ Failed to get admin user ID"
                      exit 1
                    fi

                    echo "✅ Admin user ID: $ADMIN_ID"

                    echo "🔄 Upgrading password to clan vars..."
                    HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
                      -X PUT "http://localhost:8080/admin/realms/master/users/$ADMIN_ID/reset-password" \
                      -H "Authorization: Bearer $TOKEN" \
                      -H "Content-Type: application/json" \
                      -d "{\"type\":\"password\",\"value\":\"$CLAN_ADMIN_PASS\",\"temporary\":false}")

                    if [ "$HTTP_CODE" = "204" ]; then
                      echo "✅ Password upgrade successful!"
                    else
                      echo "❌ Password upgrade failed (HTTP $HTTP_CODE)"
                      exit 1
                    fi

                    echo "🧪 Testing authentication with clan vars password..."
                    if curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                        -d "client_id=admin-cli&username=admin&password=$CLAN_ADMIN_PASS&grant_type=password" \
                        | grep -q "access_token"; then
                      echo "✅ Authentication successful with clan vars password!"
                    else
                      echo "❌ Authentication failed with new password"
                      exit 1
                    fi

                    echo "🎯 Phase 2 Complete: Admin password upgraded to secure clan vars"
                  '';
                in ''
                  ${upgradeScript}
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

              # Phase 2: Automatic admin password upgrade (always enabled for security)
              systemd.services."keycloak-${instanceName}-password-upgrade" = {
                description = "Upgrade Keycloak admin password to clan vars";
                after = [ "keycloak.service" ];
                requires = [ "keycloak.service" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  User = "keycloak";
                  Group = "keycloak";
                  LoadCredential = [ "admin_password:${adminPasswordFile}" ];
                };

                script = let
                  upgradeScript = pkgs.writeShellScript "upgrade-admin-password" ''
                    set -e
                    echo "🔄 Phase 2: Upgrading admin password to clan vars"

                    # Wait for Keycloak to be fully ready
                    for i in {1..30}; do
                      if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ | grep -q "200"; then
                        echo "✅ Keycloak is ready"
                        break
                      fi
                      sleep 5
                    done

                    # Get clan vars password
                    CLAN_ADMIN_PASS=$(cat $CREDENTIALS_DIRECTORY/admin_password)

                    # Test if password is already upgraded
                    if curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                        -d "client_id=admin-cli&username=admin&password=$CLAN_ADMIN_PASS&grant_type=password" \
                        | grep -q "access_token"; then
                      echo "✅ Password already upgraded to clan vars"
                      exit 0
                    fi

                    # Get bootstrap token and upgrade password
                    TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
                      -d "client_id=admin-cli&username=admin&password=TempAdmin123&grant_type=password" | \
                      ${pkgs.jq}/bin/jq -r .access_token)

                    if [ "$TOKEN" = "null" ]; then
                      echo "❌ Failed to get bootstrap token"
                      exit 1
                    fi

                    ADMIN_ID=$(curl -s "http://localhost:8080/admin/realms/master/users?username=admin" \
                      -H "Authorization: Bearer $TOKEN" | ${pkgs.jq}/bin/jq -r '.[0].id')

                    curl -s -X PUT "http://localhost:8080/admin/realms/master/users/$ADMIN_ID/reset-password" \
                      -H "Authorization: Bearer $TOKEN" \
                      -H "Content-Type: application/json" \
                      -d "{\"type\":\"password\",\"value\":\"$CLAN_ADMIN_PASS\",\"temporary\":false}"

                    echo "✅ Phase 2 Complete: Admin password upgraded to clan vars"
                  '';
                in ''
                  ${upgradeScript}
                '';
              };

              # Terraform integration with secure password (if enabled)
            } // lib.optionalAttrs (settings.terraform.enable or false) {
              # Create terraform configuration directory
              systemd.tmpfiles.rules = [
                "d /var/lib/keycloak-${instanceName}-terraform 0755 keycloak keycloak -"
              ];

              # Generate terraform configuration with environment variable model
              systemd.services."keycloak-${instanceName}-terraform-init" = {
                description = "Initialize Terraform configuration for Keycloak ${instanceName}";
                after = [ "keycloak-${instanceName}-password-upgrade.service" ];  # After password upgrade
                requires = [ "keycloak-${instanceName}-password-upgrade.service" ];
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
            };
        };
    };
  };
}
