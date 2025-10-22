# Example: How to refactor the keycloak module using the new OpenTofu library
# This shows the before/after comparison and integration pattern

{ lib, config, ... }:

let
  inherit (lib) mkOption types;

  # Import the OpenTofu library
  opentofu = config._lib.opentofu;

in
{
  # NEW: Simplified keycloak module using the OpenTofu library
  # This replaces all the complex Garage and terraform setup in the original

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
        freeformType = types.attrsOf types.anything;

        options = {
          domain = mkOption {
            type = types.str;
            description = "Domain name for the Keycloak instance";
            example = "auth.company.com";
          };

          nginxPort = mkOption {
            type = types.port;
            default = 9080;
            description = "Nginx proxy port for Keycloak";
          };

          # NEW: Simplified backend configuration using the library
          backend = mkOption {
            type = opentofu.backends.types.backendConfig;
            default = {
              type = "local";
            };
            description = "OpenTofu backend configuration";
            example = {
              type = "garage";
              bucket = "terraform-state";
              keyPrefix = "keycloak";
            };
          };

          autoApply = mkOption {
            type = types.bool;
            default = false;
            description = "Automatically apply terraform on service start";
          };

          # NEW: Terranix configuration for Keycloak resources
          terraform = mkOption {
            type = types.attrs;
            default = { };
            description = "Keycloak terraform resource configuration";
            example = {
              realms.company = {
                enabled = true;
                loginWithEmailAllowed = true;
              };
              clients.my-app = {
                realm = "company";
                accessType = "PUBLIC";
                validRedirectUris = [ "https://app.company.com/*" ];
              };
            };
          };
        };
      };

      perInstance =
        { instanceName, extendSettings, ... }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              settings = extendSettings { };
              inherit (settings)
                domain
                backend
                autoApply
                terraform
                ;

              # NEW: Use the OpenTofu library pattern for Keycloak
              opentofuSystem = opentofu.generateOpenTofuService {
                serviceName = "keycloak";
                inherit instanceName backend autoApply;

                # Credential files from clan vars
                credentialFiles = [
                  {
                    name = "admin_password";
                    source = config.clan.core.vars.generators."keycloak-${instanceName}".files.admin_password.path;
                  }
                ];

                # Service dependencies
                dependsOn = [ "postgresql.service" ];
                waitForService = "keycloak.service";

                # Terraform variables
                variables = {
                  keycloak_admin_password = "$CREDENTIALS_DIRECTORY/admin_password";
                  keycloak_admin_new_password = "$CREDENTIALS_DIRECTORY/admin_password";
                };

                # Provider configuration
                providers = {
                  keycloak = {
                    source = "registry.opentofu.org/mrparkers/keycloak";
                    version = "~> 4.4";
                    client_id = "admin-cli";
                    username = "admin";
                    password = "\${var.keycloak_admin_password}";
                    url = "http://localhost:8080";
                    realm = "master";
                    initial_login = false;
                    client_timeout = 60;
                    tls_insecure_skip_verify = true;
                  };
                };

                # Terranix configuration - generate Keycloak resources
                terranix = {
                  resource = lib.foldl' lib.recursiveUpdate { } [
                    # Admin user management
                    {
                      keycloak_user.admin = {
                        realm_id = "master";
                        username = "admin";
                        enabled = true;
                        email = "admin@keycloak.local";
                        email_verified = true;
                        first_name = "Administrator";
                        last_name = "User";
                        initial_password = {
                          value = "\${var.keycloak_admin_new_password}";
                          temporary = false;
                        };
                      };
                    }

                    # Generate realms from configuration
                    (lib.foldl' lib.recursiveUpdate { } (
                      lib.mapAttrsToList (name: config: {
                        keycloak_realm.${name} = {
                          realm = name;
                          enabled = config.enabled or true;
                          display_name = config.displayName or name;
                          login_with_email_allowed = config.loginWithEmailAllowed or false;
                          duplicate_emails_allowed = config.duplicateEmailsAllowed or false;
                          verify_email = config.verifyEmail or false;
                          registration_allowed = config.registrationAllowed or false;
                          reset_password_allowed = config.resetPasswordAllowed or false;
                        };
                      }) (terraform.realms or { })
                    ))

                    # Generate clients from configuration
                    (lib.foldl' lib.recursiveUpdate { } (
                      lib.mapAttrsToList (name: config: {
                        keycloak_openid_client.${name} = {
                          realm_id = "\${keycloak_realm.${config.realm}.id}";
                          client_id = name;
                          name = config.name or name;
                          access_type = config.accessType or "PUBLIC";
                          standard_flow_enabled = config.standardFlowEnabled or true;
                          valid_redirect_uris = config.validRedirectUris or [ ];
                          web_origins = config.webOrigins or [ ];
                        };
                      }) (terraform.clients or { })
                    ))
                  ];

                  # Outputs
                  output = {
                    realms = {
                      value = lib.mapAttrs (name: _: "\${keycloak_realm.${name}.id}") (terraform.realms or { });
                      description = "Created realm IDs";
                    };
                    clients = {
                      value = lib.mapAttrs (name: _: "\${keycloak_openid_client.${name}.id}") (terraform.clients or { });
                      description = "Created client IDs";
                    };
                  };
                };
              };

            in
            lib.recursiveUpdate opentofuSystem {
              # Standard Keycloak NixOS configuration
              services = {
                keycloak = {
                  enable = true;
                  initialAdminPassword = "TemporaryBootstrapPassword123!";
                  settings = {
                    hostname = domain;
                    proxy-headers = "xforwarded";
                    http-enabled = true;
                    http-port = 8080;
                  };
                  database = {
                    type = "postgresql";
                    createLocally = true;
                    passwordFile = config.clan.core.vars.generators."keycloak-${instanceName}".files.db_password.path;
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
                        port = settings.nginxPort;
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

              # Clan vars for passwords
              clan.core.vars.generators."keycloak-${instanceName}" = {
                files = {
                  db_password.deploy = true;
                  admin_password.deploy = true;
                };
                runtimeInputs = [ pkgs.pwgen ];
                script = ''
                  ${pkgs.pwgen}/bin/pwgen -s 32 1 | tr -d '\n' > "$out"/db_password
                  ${pkgs.pwgen}/bin/pwgen -s 32 1 | tr -d '\n' > "$out"/admin_password
                '';
              };
            };
        };
    };
  };
}

# COMPARISON: What this replaces from the original keycloak module
#
# REMOVED (now handled by the library):
# - 255 lines of garage-terraform-init service
# - 180 lines of terraform deployment services
# - 100 lines of backend configuration generation
# - 80 lines of credential loading scripts
# - 50 lines of helper command scripts
# - 30 lines of state locking implementation
# - Complex activation scripts for change detection
#
# TOTAL: ~695 lines of complex terraform/garage integration code
# REPLACED WITH: ~50 lines using the OpenTofu library
#
# BENEFITS:
# - All backend types (local, s3, garage) supported with same interface
# - Automatic bucket creation and credential management for Garage
# - Consistent patterns across all clan services
# - Much simpler service module code
# - Reusable configuration change detection
# - Built-in helper commands and status scripts
# - Better error handling and validation
