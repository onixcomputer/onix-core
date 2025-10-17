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

          terraform = {
            enable = mkEnableOption "Terraform-managed Keycloak resources";

            realms = mkOption {
              type = attrsOf (submodule {
                options = {
                  enabled = mkOption {
                    type = bool;
                    default = true;
                    description = "Whether the realm is enabled";
                  };
                  displayName = mkOption {
                    type = str;
                    description = "Display name for the realm";
                  };
                  loginWithEmailAllowed = mkOption {
                    type = bool;
                    default = true;
                    description = "Allow login with email";
                  };
                  registrationAllowed = mkOption {
                    type = bool;
                    default = false;
                    description = "Allow user registration";
                  };
                  verifyEmail = mkOption {
                    type = bool;
                    default = true;
                    description = "Require email verification";
                  };
                  sslRequired = mkOption {
                    type = str;
                    default = "external";
                    description = "SSL requirement (none, external, all)";
                  };
                  passwordPolicy = mkOption {
                    type = str;
                    default = "upperCase(1) and length(8) and notUsername";
                    description = "Password policy for the realm";
                  };
                };
              });
              default = {};
              description = "Keycloak realms to manage via Terraform";
              example = {
                production = {
                  displayName = "Production Environment";
                  registrationAllowed = false;
                  verifyEmail = true;
                };
              };
            };

            clients = mkOption {
              type = attrsOf (submodule {
                options = {
                  realm = mkOption {
                    type = str;
                    description = "Realm this client belongs to";
                  };
                  name = mkOption {
                    type = str;
                    description = "Human-readable name for the client";
                  };
                  accessType = mkOption {
                    type = str;
                    default = "CONFIDENTIAL";
                    description = "Access type (PUBLIC, CONFIDENTIAL, BEARER-ONLY)";
                  };
                  standardFlowEnabled = mkOption {
                    type = bool;
                    default = true;
                    description = "Enable standard flow (authorization code)";
                  };
                  directAccessGrantsEnabled = mkOption {
                    type = bool;
                    default = false;
                    description = "Enable direct access grants (password flow)";
                  };
                  serviceAccountsEnabled = mkOption {
                    type = bool;
                    default = false;
                    description = "Enable service accounts";
                  };
                  validRedirectUris = mkOption {
                    type = listOf str;
                    default = [];
                    description = "Valid redirect URIs";
                  };
                  webOrigins = mkOption {
                    type = listOf str;
                    default = [];
                    description = "Valid web origins";
                  };
                };
              });
              default = {};
              description = "Keycloak OIDC clients to manage via Terraform";
              example = {
                web-app = {
                  realm = "production";
                  name = "Web Application";
                  validRedirectUris = ["https://app.example.com/auth/callback"];
                };
              };
            };

            users = mkOption {
              type = attrsOf (submodule {
                options = {
                  realm = mkOption {
                    type = str;
                    description = "Realm this user belongs to";
                  };
                  email = mkOption {
                    type = str;
                    description = "User email";
                  };
                  firstName = mkOption {
                    type = str;
                    description = "User first name";
                  };
                  lastName = mkOption {
                    type = str;
                    description = "User last name";
                  };
                  enabled = mkOption {
                    type = bool;
                    default = true;
                    description = "Whether the user is enabled";
                  };
                  emailVerified = mkOption {
                    type = bool;
                    default = false;
                    description = "Whether the user's email is verified";
                  };
                  initialPassword = mkOption {
                    type = str;
                    description = "Initial password for the user";
                  };
                  temporary = mkOption {
                    type = bool;
                    default = true;
                    description = "Whether the initial password is temporary";
                  };
                };
              });
              default = {};
              description = "Keycloak users to manage via Terraform";
            };

            groups = mkOption {
              type = attrsOf (submodule {
                options = {
                  realm = mkOption {
                    type = str;
                    description = "Realm this group belongs to";
                  };
                  parentGroup = mkOption {
                    type = lib.types.nullOr str;
                    default = null;
                    description = "Parent group name";
                  };
                  attributes = mkOption {
                    type = attrsOf str;
                    default = {};
                    description = "Group attributes";
                  };
                };
              });
              default = {};
              description = "Keycloak groups to manage via Terraform";
            };

            roles = mkOption {
              type = attrsOf (submodule {
                options = {
                  realm = mkOption {
                    type = str;
                    description = "Realm this role belongs to";
                  };
                  client = mkOption {
                    type = lib.types.nullOr str;
                    default = null;
                    description = "Client this role belongs to (null for realm roles)";
                  };
                  description = mkOption {
                    type = str;
                    description = "Role description";
                  };
                };
              });
              default = {};
              description = "Keycloak roles to manage via Terraform";
            };
          };
        };
      };

      perInstance =
        { instanceName, extendSettings, ... }:
        let
          settings = extendSettings { };
          inherit (settings) domain;
          nginxPort = settings.nginxPort or 9080;
          terraformConfig = settings.terraform or {};
          terraformEnabled = terraformConfig.enable or false;
        in
        {
          nixosModule =
            {
              config,
              pkgs,
              ...
            }:
            let
              keycloakSettings = builtins.removeAttrs settings [
                "domain"
                "nginxPort"
                "terraform"
              ];

              generatorName = "keycloak-${instanceName}";
              dbPasswordFile = config.clan.core.vars.generators.${generatorName}.files.db_password.path;
              adminPasswordFile = config.clan.core.vars.generators.${generatorName}.files.admin_password.path;
            in
            {
              # NUCLEAR OPTION: Complete service removal for fresh start
              # All services disabled to clean slate
              /*
              services = {
                keycloak = {
                  enable = true;
                  initialAdminPassword = "admin-adeci";
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

              # Ensure proper service startup order and bootstrap admin
              systemd.services.keycloak = {
                # Add dependencies for PostgreSQL
                after = [ "postgresql.service" ];
                requires = [ "postgresql.service" ];

                # Enhanced pre-start script for admin setup
                preStart = ''
                  echo "=== Keycloak Admin Creation Setup ==="
                  echo "Using environment variables for reliable admin user creation:"
                  echo "1. KC_BOOTSTRAP_* environment variables (primary method)"
                  echo "2. KEYCLOAK_ADMIN environment variables (legacy fallback)"

                  # Wait for database
                  while ! ${config.services.postgresql.package}/bin/pg_isready -h localhost; do
                    echo "Waiting for PostgreSQL to be ready..."
                    sleep 2
                  done
                  echo "✓ PostgreSQL is ready"

                  # Ensure proper directory permissions
                  mkdir -p /var/lib/keycloak
                  chown -R keycloak:keycloak /var/lib/keycloak || true

                  echo "Admin username: admin"
                  echo "Admin password: admin-adeci"
                  echo "Expected URL: https://${domain}/admin/"
                  echo "=================================="
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

              # Terraform integration for Keycloak resources
            } // lib.optionalAttrs terraformEnabled {
              # Create terraform configuration directory with proper permissions
              systemd.tmpfiles.rules = [
                "d /var/lib/keycloak-${instanceName}-terraform 0755 keycloak keycloak -"
                "f /var/lib/keycloak-${instanceName}-terraform/main.tf.json 0644 keycloak keycloak -"
                "f /var/lib/keycloak-${instanceName}-terraform/terraform.tfvars 0644 keycloak keycloak -"
                "f /var/lib/keycloak-${instanceName}-terraform/backend.tf 0644 keycloak keycloak -"
                "f /var/lib/keycloak-${instanceName}-terraform/manage.sh 0755 keycloak keycloak -"
              ];

              # Generate terraform configuration when enabled
              systemd.services."keycloak-${instanceName}-terraform-init" = {
                description = "Initialize Terraform configuration for Keycloak ${instanceName}";
                wantedBy = [ "multi-user.target" ];
                after = [ "keycloak.service" ];
                requires = [ "keycloak.service" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  User = "keycloak";
                  Group = "keycloak";
                  WorkingDirectory = "/var/lib/keycloak-${instanceName}-terraform";
                  LoadCredential = [
                    "admin_password:${adminPasswordFile}"
                    "db_password:${dbPasswordFile}"
                  ];
                };

                script = ''
                  # Generate basic terraform configuration that works
                  cat > main.tf.json <<'EOF'
{
  "terraform": {
    "required_providers": {
      "keycloak": {
        "source": "registry.opentofu.org/mrparkers/keycloak",
        "version": "~> 4.0"
      }
    },
    "required_version": ">= 1.0.0"
  },
  "variable": {
    "keycloak_url": {
      "description": "Keycloak server URL",
      "type": "string"
    },
    "keycloak_realm": {
      "description": "Keycloak realm for provider authentication",
      "type": "string",
      "default": "master"
    },
    "keycloak_admin_username": {
      "description": "Keycloak admin username",
      "type": "string",
      "default": "admin"
    },
    "keycloak_admin_password": {
      "description": "Keycloak admin password",
      "type": "string",
      "sensitive": true
    },
    "keycloak_client_id": {
      "description": "Keycloak client ID for admin-cli",
      "type": "string",
      "default": "admin-cli"
    }
  },
  "provider": {
    "keycloak": {
      "client_id": "''${var.keycloak_client_id}",
      "username": "''${var.keycloak_admin_username}",
      "password": "''${var.keycloak_admin_password}",
      "url": "''${var.keycloak_url}",
      "realm": "''${var.keycloak_realm}",
      "initial_login": false,
      "client_timeout": 60,
      "tls_insecure_skip_verify": false
    }
  },
  "resource": {
    "keycloak_realm": {
      "production": {
        "realm": "production",
        "enabled": true,
        "display_name": "Production Environment",
        "login_with_email_allowed": true,
        "registration_allowed": false,
        "verify_email": true,
        "ssl_required": "external",
        "password_policy": "upperCase(1) and lowerCase(1) and length(12) and notUsername"
      },
      "development": {
        "realm": "development",
        "enabled": true,
        "display_name": "Development Environment",
        "login_with_email_allowed": true,
        "registration_allowed": true,
        "verify_email": false,
        "ssl_required": "external",
        "password_policy": "length(8) and notUsername"
      }
    },
    "keycloak_openid_client": {
      "web_app_prod": {
        "realm_id": "''${keycloak_realm.production.id}",
        "client_id": "web-app-prod",
        "name": "Production Web Application",
        "access_type": "CONFIDENTIAL",
        "standard_flow_enabled": true,
        "direct_access_grants_enabled": false,
        "service_accounts_enabled": false,
        "valid_redirect_uris": ["https://app.robitzs.ch/auth/callback"],
        "web_origins": ["https://app.robitzs.ch"]
      },
      "api_service": {
        "realm_id": "''${keycloak_realm.production.id}",
        "client_id": "api-service",
        "name": "API Service",
        "access_type": "CONFIDENTIAL",
        "standard_flow_enabled": false,
        "direct_access_grants_enabled": false,
        "service_accounts_enabled": true,
        "valid_redirect_uris": [],
        "web_origins": []
      },
      "dev_app": {
        "realm_id": "''${keycloak_realm.development.id}",
        "client_id": "dev-app",
        "name": "Development Application",
        "access_type": "PUBLIC",
        "standard_flow_enabled": true,
        "direct_access_grants_enabled": true,
        "service_accounts_enabled": false,
        "valid_redirect_uris": ["http://localhost:3000/auth/callback"],
        "web_origins": ["http://localhost:3000"]
      }
    },
    "keycloak_user": {
      "admin_user": {
        "realm_id": "''${keycloak_realm.production.id}",
        "username": "admin-user",
        "email": "admin@robitzs.ch",
        "first_name": "Admin",
        "last_name": "User",
        "enabled": true,
        "email_verified": true,
        "initial_password": {
          "value": "TempAdminPass123!",
          "temporary": true
        }
      },
      "test_user": {
        "realm_id": "''${keycloak_realm.development.id}",
        "username": "test-user",
        "email": "test@robitzs.ch",
        "first_name": "Test",
        "last_name": "User",
        "enabled": true,
        "email_verified": false,
        "initial_password": {
          "value": "TestPass123",
          "temporary": false
        }
      }
    },
    "keycloak_group": {
      "administrators": {
        "realm_id": "''${keycloak_realm.production.id}",
        "name": "administrators",
        "parent_id": null,
        "attributes": {
          "department": "IT",
          "description": "System administrators"
        }
      },
      "developers": {
        "realm_id": "''${keycloak_realm.development.id}",
        "name": "developers",
        "parent_id": null,
        "attributes": {
          "department": "Engineering",
          "description": "Development team"
        }
      },
      "senior_developers": {
        "realm_id": "''${keycloak_realm.development.id}",
        "name": "senior-developers",
        "parent_id": "''${keycloak_group.developers.id}",
        "attributes": {
          "description": "Senior development team",
          "level": "senior"
        }
      }
    },
    "keycloak_role": {
      "admin": {
        "realm_id": "''${keycloak_realm.production.id}",
        "name": "admin",
        "description": "Administrator role with full access"
      },
      "user": {
        "realm_id": "''${keycloak_realm.production.id}",
        "name": "user",
        "description": "Standard user role"
      },
      "api_access": {
        "realm_id": "''${keycloak_realm.production.id}",
        "client_id": "''${keycloak_openid_client.api_service.id}",
        "name": "api-access",
        "description": "API access role for service accounts"
      },
      "developer": {
        "realm_id": "''${keycloak_realm.development.id}",
        "name": "developer",
        "description": "Developer role for development environment"
      }
    }
  },
  "output": {
    "keycloak_instance_info": {
      "value": {
        "url": "''${var.keycloak_url}",
        "admin_console": "''${var.keycloak_url}/admin",
        "instance_name": "${instanceName}",
        "production_realm": "''${keycloak_realm.production.id}",
        "development_realm": "''${keycloak_realm.development.id}",
        "web_app_client": "''${keycloak_openid_client.web_app_prod.id}",
        "api_service_client": "''${keycloak_openid_client.api_service.id}"
      },
      "description": "Keycloak instance information for ${instanceName}"
    }
  }
}
EOF

                  # Automatic variable bridge: clan vars -> terraform variables
                  echo "# Terraform variables automatically generated from clan vars" > terraform.tfvars
                  echo "# Generated on: $(date)" >> terraform.tfvars
                  echo "" >> terraform.tfvars

                  # Core authentication variables
                  echo "# Keycloak authentication variables" >> terraform.tfvars
                  echo "keycloak_admin_password = \"admin-adeci\"" >> terraform.tfvars
                  echo "keycloak_url = \"https://${domain}\"" >> terraform.tfvars
                  echo "keycloak_realm = \"master\"" >> terraform.tfvars
                  echo "keycloak_admin_username = \"admin\"" >> terraform.tfvars
                  echo "keycloak_client_id = \"admin-cli\"" >> terraform.tfvars
                  echo "" >> terraform.tfvars

                  # Database connection variables
                  echo "# Database connection variables" >> terraform.tfvars
                  echo "keycloak_db_password = \"$(cat $CREDENTIALS_DIRECTORY/db_password)\"" >> terraform.tfvars
                  echo "" >> terraform.tfvars

                  # Additional variables for advanced configurations
                  echo "# Advanced configuration" >> terraform.tfvars
                  echo "keycloak_client_timeout = 60" >> terraform.tfvars
                  echo "keycloak_initial_login = false" >> terraform.tfvars
                  echo "keycloak_tls_insecure_skip_verify = false" >> terraform.tfvars
                  echo "" >> terraform.tfvars

                  # Instance-specific variables
                  echo "# Instance configuration" >> terraform.tfvars
                  echo "instance_name = \"${instanceName}\"" >> terraform.tfvars
                  echo "domain = \"${domain}\"" >> terraform.tfvars
                  echo "nginx_port = ${toString nginxPort}" >> terraform.tfvars

                  # Create a backup of the variables file (if writable)
                  cp terraform.tfvars terraform.tfvars.backup 2>/dev/null || echo "Backup file already exists"

                  # Generate terraform backend configuration for state management
                  cat > backend.tf <<EOF
# Terraform backend configuration for Keycloak instance: ${instanceName}
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF

                  # Create a convenience script for terraform operations
                  cat > manage.sh <<'SCRIPT'
#!${pkgs.bash}/bin/bash
# Keycloak Terraform Management Script
# Generated automatically by clan service

set -e

INSTANCE_NAME="${instanceName}"
DOMAIN="${domain}"

echo "🔑 Keycloak Terraform Management for instance: $INSTANCE_NAME"
echo "🌐 Domain: $DOMAIN"
echo "📁 Working directory: $(pwd)"
echo

case "''${1:-help}" in
  init)
    echo "🚀 Initializing Terraform..."
    ${pkgs.opentofu}/bin/tofu init
    ;;
  plan)
    echo "📋 Planning Terraform changes..."
    ${pkgs.opentofu}/bin/tofu plan -var-file=terraform.tfvars
    ;;
  apply)
    echo "✅ Applying Terraform configuration..."
    ${pkgs.opentofu}/bin/tofu apply -var-file=terraform.tfvars
    ;;
  destroy)
    echo "💥 Destroying Terraform resources..."
    read -p "Are you sure you want to destroy all resources? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
      ${pkgs.opentofu}/bin/tofu destroy -var-file=terraform.tfvars
    else
      echo "Destroy cancelled."
    fi
    ;;
  status)
    echo "📊 Terraform status..."
    if [ -f terraform.tfstate ]; then
      ${pkgs.opentofu}/bin/tofu show -json terraform.tfstate | ${pkgs.jq}/bin/jq '.values.root_module.resources[] | {type: .type, name: .name, address: .address}' 2>/dev/null || echo "Install jq for better output formatting"
    else
      echo "No terraform state found. Run './manage.sh init' first."
    fi
    ;;
  refresh)
    echo "🔄 Refreshing variable bridge..."
    systemctl restart keycloak-${instanceName}-terraform-init.service
    echo "Variables refreshed from clan vars"
    ;;
  help|*)
    echo "Usage: $0 {init|plan|apply|destroy|status|refresh|help}"
    echo
    echo "Commands:"
    echo "  init     - Initialize Terraform working directory"
    echo "  plan     - Show planned Terraform changes"
    echo "  apply    - Apply Terraform configuration"
    echo "  destroy  - Destroy all Terraform resources"
    echo "  status   - Show current Terraform state"
    echo "  refresh  - Refresh variables from clan vars"
    echo "  help     - Show this help message"
    echo
    echo "Examples:"
    echo "  $0 init && $0 plan && $0 apply"
    echo "  $0 status"
    echo "  $0 refresh && $0 apply"
    ;;
esac
SCRIPT

                  chmod +x manage.sh

                  echo "✅ Terraform configuration generated for Keycloak instance: ${instanceName}"
                  echo "📁 Working directory: /var/lib/keycloak-${instanceName}-terraform"
                  echo "🔧 Management script: ./manage.sh"
                  echo ""
                  echo "Quick start:"
                  echo "  ./manage.sh init    # Initialize Terraform"
                  echo "  ./manage.sh plan    # Preview changes"
                  echo "  ./manage.sh apply   # Apply changes"
                  echo ""
                  echo "Variables automatically bridged from clan vars:"
                  echo "  ✓ keycloak_admin_password (from clan var)"
                  echo "  ✓ keycloak_url (from domain setting)"
                  echo "  ✓ Authentication configuration"
                  echo "  ✓ Instance configuration"
                '';
              };
            };

          */ # End nuclear removal comment

          # Empty nixosModule during nuclear removal
          nixosModule = {};
        };
    };
  };
}
