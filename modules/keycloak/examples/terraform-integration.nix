{
  # Example: Migrating from cloud/keycloak-*.nix to integrated Keycloak service
  # This demonstrates how to use the new terraform integration with the clan Keycloak service

  # Before: Separate cloud terraform files and manual variable management
  # After: Unified configuration through clan service with automatic terraform generation

  inventory.instances = {
    keycloak-production = {
      module = {
        name = "keycloak";
        input = "clan-core"; # or omit for local module
      };

      roles.server.machines.auth-server = {
        settings = {
          domain = "auth.robitzs.ch";
          nginxPort = 9081;

          # Enable terraform resource management
          terraform = {
            enable = true;

            # Realm configuration (migrated from keycloak-admin-cli.nix)
            realms = {
              production = {
                enabled = true;
                displayName = "Production Environment";
                displayNameHtml = "<h1>Production Environment</h1>";

                # Login settings
                loginWithEmailAllowed = true;
                duplicateEmailsAllowed = false;
                verifyEmail = true;
                registrationAllowed = true;
                registrationEmailAsUsername = true;
                resetPasswordAllowed = true;
                rememberMe = true;

                # Security settings
                sslRequired = "external";
                passwordPolicy = "upperCase(1) and length(8) and forceExpiredPasswordChange(365) and notUsername";

                # Session settings
                ssoSessionIdleTimeout = "30m";
                ssoSessionMaxLifespan = "10h";
                offlineSessionIdleTimeout = "720h";
                offlineSessionMaxLifespan = "8760h";

                # Themes
                loginTheme = "base";
                adminTheme = "base";
                accountTheme = "base";
                emailTheme = "base";

                # Internationalization
                internationalization = {
                  supportedLocales = [
                    "en"
                    "de"
                    "fr"
                  ];
                  defaultLocale = "en";
                };
              };

              development = {
                enabled = true;
                displayName = "Development Environment";
                displayNameHtml = "<h1>Development Environment</h1>";

                # Relaxed settings for development
                registrationAllowed = true;
                verifyEmail = false;
                sslRequired = "external";
                passwordPolicy = "length(6)";
              };
            };

            # Client configuration (migrated from keycloak-admin-cli.nix)
            clients = {
              web-app = {
                realm = "production";
                name = "Web Application";
                description = "Main web application client";

                # Security configuration
                accessType = "CONFIDENTIAL";
                standardFlowEnabled = true;
                implicitFlowEnabled = false;
                directAccessGrantsEnabled = false;
                serviceAccountsEnabled = false;

                # URLs and redirects
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

                # PKCE for enhanced security
                pkceCodeChallengeMethod = "S256";
              };

              mobile-app = {
                realm = "production";
                name = "Mobile Application";
                description = "Mobile application client";

                # Public client for mobile
                accessType = "PUBLIC";
                standardFlowEnabled = true;
                implicitFlowEnabled = false;
                directAccessGrantsEnabled = true;

                # Mobile-specific redirects
                validRedirectUris = [
                  "com.example.app://oauth/callback"
                  "http://localhost:3000/auth/callback"
                ];

                # PKCE required for public clients
                pkceCodeChallengeMethod = "S256";
              };

              api-service = {
                realm = "production";
                name = "API Service";
                description = "Backend API service";

                # Service account client
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

                # Relaxed settings for development
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

            # Group configuration (migrated from keycloak-admin-cli.nix)
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

            # Role configuration (migrated from keycloak-admin-cli.nix)
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

              # Client-specific roles
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

              # Development roles
              dev-role = {
                realm = "development";
                description = "Developer access role";
              };
            };

            # User configuration (migrated from keycloak-admin-cli.nix)
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
          };

          # Additional Keycloak service settings can be added here
          # These will be passed to the underlying NixOS Keycloak service
          settings = {
            # Any additional NixOS Keycloak service configuration
            features = "authorization,account2";
            http-relative-path = "/auth";
          };
        };
      };
    };
  };

  # The above configuration will automatically:
  # 1. Deploy a NixOS Keycloak service with PostgreSQL
  # 2. Generate clan vars for database and admin passwords
  # 3. Create terraform configuration files in /var/lib/keycloak-production-terraform/
  # 4. Bridge clan vars to terraform variables automatically
  # 5. Provide service exports for other services to consume

  # Migration Benefits:
  # - Single configuration point for both NixOS service and Terraform resources
  # - Automatic secret management with clan vars
  # - Type-safe configuration with Nix
  # - Service discovery through exports
  # - Unified deployment workflow

  # To apply the terraform configuration:
  # 1. Deploy the clan configuration: `clan machines deploy`
  # 2. SSH to the auth-server machine
  # 3. Navigate to: `cd /var/lib/keycloak-production-terraform`
  # 4. Initialize: `tofu init`
  # 5. Plan: `tofu plan`
  # 6. Apply: `tofu apply`

  # Advanced: Use devshell integration for unified management:
  # `cloud keycloak status` - Check both service and terraform status
  # `cloud keycloak apply` - Apply terraform configuration
  # `cloud keycloak destroy` - Destroy terraform resources
}
