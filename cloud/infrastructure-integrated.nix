# Integrated Infrastructure Configuration
# This demonstrates the new integrated approach using clan services
# instead of direct terraform configuration

{ ... }:
{
  # This file shows how to migrate from the legacy infrastructure.nix approach
  # to the new integrated clan service approach

  # OLD APPROACH (infrastructure.nix):
  # - Direct terraform resource definitions
  # - Manual variable management
  # - Separate clan vars integration

  # NEW APPROACH (clan service integration):
  # - Service-based configuration through clan inventory
  # - Automatic terraform generation
  # - Built-in variable bridge
  # - Unified deployment workflow

  # Note: This file serves as documentation and comparison
  # The actual integrated configuration should be defined in your clan configuration
  # See: modules/keycloak/examples/terraform-integration.nix

  # Legacy terraform configuration equivalent (for reference):
  imports = [
    # These are no longer needed in the integrated approach:
    # ./keycloak-variables.nix
    # ./keycloak-admin-cli.nix
  ];

  # Instead, the integrated approach uses clan inventory configuration:
  # This would typically be in your flake.nix or a separate clan configuration file

  /*
  # Integrated clan configuration (should be in flake.nix):

  inventory.instances = {
    # Keycloak instance with integrated terraform support
    keycloak-production = {
      module = {
        name = "keycloak";
        input = "clan-core";  # or omit for local module
      };

      roles.server.machines.aspen1 = {
        settings = {
          domain = "auth.robitzs.ch";
          nginxPort = 9081;

          # Enable terraform resource management
          terraform = {
            enable = true;

            # All the resources from keycloak-admin-cli.nix are now configured here
            realms = {
              production = {
                enabled = true;
                displayName = "Production Environment";
                displayNameHtml = "<h1>Production Environment</h1>";
                loginWithEmailAllowed = true;
                duplicateEmailsAllowed = false;
                verifyEmail = true;
                registrationAllowed = true;
                registrationEmailAsUsername = true;
                resetPasswordAllowed = true;
                rememberMe = true;
                sslRequired = "external";
                passwordPolicy = "upperCase(1) and length(8) and forceExpiredPasswordChange(365) and notUsername";
                ssoSessionIdleTimeout = "30m";
                ssoSessionMaxLifespan = "10h";
                offlineSessionIdleTimeout = "720h";
                offlineSessionMaxLifespan = "8760h";
                loginTheme = "base";
                adminTheme = "base";
                accountTheme = "base";
                emailTheme = "base";
                internationalization = {
                  supportedLocales = ["en" "de" "fr"];
                  defaultLocale = "en";
                };
              };

              development = {
                enabled = true;
                displayName = "Development Environment";
                displayNameHtml = "<h1>Development Environment</h1>";
                registrationAllowed = true;
                verifyEmail = false;
                sslRequired = "external";
                passwordPolicy = "length(6)";
              };
            };

            clients = {
              web-app = {
                realm = "production";
                name = "Web Application";
                description = "Main web application client";
                accessType = "CONFIDENTIAL";
                standardFlowEnabled = true;
                implicitFlowEnabled = false;
                directAccessGrantsEnabled = false;
                serviceAccountsEnabled = false;
                validRedirectUris = [
                  "https://app.example.com/auth/callback"
                  "https://app.example.com/oauth2/callback"
                ];
                validPostLogoutRedirectUris = [
                  "https://app.example.com/logout"
                ];
                webOrigins = [
                  "https://app.example.com"
                ];
                pkceCodeChallengeMethod = "S256";
              };

              mobile-app = {
                realm = "production";
                name = "Mobile Application";
                description = "Mobile application client";
                accessType = "PUBLIC";
                standardFlowEnabled = true;
                implicitFlowEnabled = false;
                directAccessGrantsEnabled = true;
                validRedirectUris = [
                  "com.example.app://oauth/callback"
                  "http://localhost:3000/auth/callback"
                ];
                pkceCodeChallengeMethod = "S256";
              };

              api-service = {
                realm = "production";
                name = "API Service";
                description = "Backend API service";
                accessType = "CONFIDENTIAL";
                serviceAccountsEnabled = true;
                standardFlowEnabled = false;
                implicitFlowEnabled = false;
                directAccessGrantsEnabled = false;
              };

              dev-client = {
                realm = "development";
                name = "Development Client";
                description = "Development testing client";
                accessType = "PUBLIC";
                standardFlowEnabled = true;
                implicitFlowEnabled = true;
                directAccessGrantsEnabled = true;
                validRedirectUris = [
                  "http://localhost:3000/*"
                  "http://localhost:8080/*"
                  "http://127.0.0.1:3000/*"
                ];
                webOrigins = [
                  "http://localhost:3000"
                  "http://localhost:8080"
                  "http://127.0.0.1:3000"
                ];
              };
            };

            groups = {
              administrators = {
                realm = "production";
                attributes = {
                  description = "System administrators with full access";
                  level = "admin";
                };
              };

              users = {
                realm = "production";
                attributes = {
                  description = "Standard application users";
                  level = "user";
                };
              };

              power-users = {
                realm = "production";
                parentGroup = "users";
                attributes = {
                  description = "Users with enhanced permissions";
                  level = "power-user";
                };
              };

              developers = {
                realm = "development";
                attributes = {
                  description = "Development team members";
                  level = "developer";
                };
              };
            };

            roles = {
              admin-role = {
                realm = "production";
                description = "Administrator role with full access";
              };

              user-role = {
                realm = "production";
                description = "Standard user role";
              };

              manager-role = {
                realm = "production";
                description = "Manager role with elevated permissions";
              };

              app-admin = {
                realm = "production";
                client = "web-app";
                description = "Application administrator";
              };

              app-user = {
                realm = "production";
                client = "web-app";
                description = "Application user";
              };

              dev-role = {
                realm = "development";
                description = "Developer access role";
              };
            };

            users = {
              admin = {
                realm = "production";
                email = "admin-terranix@example.com";
                firstName = "System";
                lastName = "Administrator";
                enabled = true;
                emailVerified = true;
                attributes = {
                  department = "IT";
                  role = "administrator";
                  employee_id = "EMP001";
                };
                initialPassword = "Admin123!";
                temporary = true;
              };

              testuser = {
                realm = "development";
                email = "test@example.com";
                firstName = "Test";
                lastName = "User";
                enabled = true;
                emailVerified = false;
                attributes = {
                  department = "Testing";
                  role = "tester";
                };
                initialPassword = "password123";
                temporary = true;
              };

              appuser = {
                realm = "production";
                email = "appuser-terranix@example.com";
                firstName = "Application";
                lastName = "User";
                enabled = true;
                emailVerified = true;
                attributes = {
                  department = "Operations";
                  role = "user";
                };
                initialPassword = "User123!";
                temporary = true;
              };
            };

            # Additional terraform resource management
            userGroupMemberships = {
              admin-groups = {
                realm = "production";
                user = "admin";
                groups = ["administrators"];
              };

              appuser-groups = {
                realm = "production";
                user = "appuser";
                groups = ["users"];
              };

              testuser-groups = {
                realm = "development";
                user = "testuser";
                groups = ["developers"];
              };
            };

            userRoleAssignments = {
              admin-roles = {
                realm = "production";
                user = "admin";
                roles = ["admin-role"];
              };

              appuser-roles = {
                realm = "production";
                user = "appuser";
                roles = ["user-role"];
              };

              testuser-roles = {
                realm = "development";
                user = "testuser";
                roles = ["dev-role"];
              };
            };

            groupRoleMappings = {
              admin-group-roles = {
                realm = "production";
                group = "administrators";
                roles = ["admin-role"];
              };

              user-group-roles = {
                realm = "production";
                group = "users";
                roles = ["user-role"];
              };
            };
          };

          # Additional NixOS Keycloak service configuration
          settings = {
            features = "authorization,account2";
            http-relative-path = "/auth";
          };
        };
      };
    };

    # Other infrastructure can still be defined using the legacy approach
    # or can be migrated to clan services as they become available
  };
  */

  # Migration Benefits:
  # 1. Single configuration point for both NixOS service and Terraform resources
  # 2. Automatic secret management with clan vars (no manual bridging)
  # 3. Type-safe configuration with validation
  # 4. Service discovery through exports
  # 5. Unified deployment workflow
  # 6. Better developer experience with IDE support

  # Deployment Workflow:
  # 1. Configure clan inventory (as shown above)
  # 2. Deploy: `clan machines deploy aspen1`
  # 3. Apply terraform: SSH to machine and run `/var/lib/keycloak-production-terraform/manage.sh apply`
  # 4. Or use devshell: `cloud keycloak-service deploy keycloak-production`

  # This file is for documentation purposes only
  # Actual configuration should be done in your clan inventory
}