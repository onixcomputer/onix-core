_: {
  instances = {
    "adeci" = {
      module.name = "keycloak";
      module.input = "self";
      roles.server = {
        machines.aspen1 = { };
        settings = {
          domain = "auth.robitzs.ch";
          nginxPort = 9081;

          settings = {
            http-port = 8080;
          };

          # Enable terraform integration
          terraform = {
            enable = true;

            # Define realms
            realms = {
              "production" = {
                displayName = "Production Environment";
                loginWithEmailAllowed = true;
                registrationAllowed = false;
                verifyEmail = true;
                sslRequired = "external";
                passwordPolicy = "upperCase(1) and lowerCase(1) and length(12) and notUsername";
              };
              "development" = {
                displayName = "Development Environment";
                loginWithEmailAllowed = true;
                registrationAllowed = true;
                verifyEmail = false;
                sslRequired = "external";
                passwordPolicy = "length(8) and notUsername";
              };
            };

            # Define OIDC clients
            clients = {
              "web-app-prod" = {
                realm = "production";
                name = "Production Web Application";
                accessType = "CONFIDENTIAL";
                standardFlowEnabled = true;
                directAccessGrantsEnabled = false;
                serviceAccountsEnabled = false;
                validRedirectUris = [ "https://app.robitzs.ch/auth/callback" ];
                webOrigins = [ "https://app.robitzs.ch" ];
              };
              "api-service" = {
                realm = "production";
                name = "API Service";
                accessType = "CONFIDENTIAL";
                standardFlowEnabled = false;
                directAccessGrantsEnabled = false;
                serviceAccountsEnabled = true;
                validRedirectUris = [ ];
                webOrigins = [ ];
              };
              "dev-app" = {
                realm = "development";
                name = "Development Application";
                accessType = "PUBLIC";
                standardFlowEnabled = true;
                directAccessGrantsEnabled = true;
                serviceAccountsEnabled = false;
                validRedirectUris = [ "http://localhost:3000/auth/callback" ];
                webOrigins = [ "http://localhost:3000" ];
              };
            };

            # Define users
            users = {
              "admin-user" = {
                realm = "production";
                email = "admin@robitzs.ch";
                firstName = "Admin";
                lastName = "User";
                enabled = true;
                emailVerified = true;
                initialPassword = "TempAdminPass123!";
                temporary = true;
              };
              "test-user" = {
                realm = "development";
                email = "test@robitzs.ch";
                firstName = "Test";
                lastName = "User";
                enabled = true;
                emailVerified = false;
                initialPassword = "TestPass123";
                temporary = false;
              };
            };

            # Define groups
            groups = {
              "administrators" = {
                realm = "production";
                parentGroup = null;
                attributes = {
                  description = "System administrators";
                  department = "IT";
                };
              };
              "developers" = {
                realm = "development";
                parentGroup = null;
                attributes = {
                  description = "Development team";
                  department = "Engineering";
                };
              };
              "senior-developers" = {
                realm = "development";
                parentGroup = "developers";
                attributes = {
                  description = "Senior development team";
                  level = "senior";
                };
              };
            };

            # Define roles
            roles = {
              "admin" = {
                realm = "production";
                client = null; # Realm role
                description = "Administrator role with full access";
              };
              "user" = {
                realm = "production";
                client = null; # Realm role
                description = "Standard user role";
              };
              "api-access" = {
                realm = "production";
                client = "api-service";
                description = "API access role for service accounts";
              };
              "developer" = {
                realm = "development";
                client = null; # Realm role
                description = "Developer role for development environment";
              };
            };
          };
        };
      };
    };
  };
}
