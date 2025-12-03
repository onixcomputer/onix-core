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

          # Enable automated terraform with S3 backend
          terraformBackend = "s3";
          terraformAutoApply = true; # Re-enabled to test with external endpoint

          # Enable terraform integration
          terraform = {
            enable = true; # Re-enabled for testing

            # Define realms
            realms = {
              # Master realm configuration (administrative - secure it)
              # NOTE: Master realm already exists by default, don't try to create it
              # "master" = {
              #   enabled = true;
              #   displayName = "Administrative Realm";
              #   loginWithEmailAllowed = false;
              #   registrationAllowed = false;
              #   verifyEmail = true;
              #   sslRequired = "all";
              #   passwordPolicy = "upperCase(1) and lowerCase(1) and length(12) and specialChars(1) and notUsername";
              #   ssoSessionIdleTimeout = "15m";
              #   ssoSessionMaxLifespan = "1h";
              #   rememberMe = false;
              #   resetPasswordAllowed = false;
              # };

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
              "shadow" = {
                displayName = "Shadow Realm";
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
              "eeeek" = {
                realm = "development";
                email = "eeek@robitzs.ch";
                firstName = "eeek";
                lastName = "Test";
                enabled = true;
                emailVerified = true;
                initialPassword = "BlockingTest456!";
                temporary = true;
              };
              "hihihi" = {
                realm = "development";
                email = "hi@robitzs.ch";
                firstName = "hi";
                lastName = "Test";
                enabled = true;
                emailVerified = true;
                initialPassword = "BlockingTest456!";
                temporary = true;
              };
              "securetester" = {
                realm = "shadow";
                email = "secure@robitzs.ch";
                firstName = "Secure";
                lastName = "Tester";
                enabled = true;
                emailVerified = true;
                initialPassword = "SecureTest789!";
                temporary = true;
              };
              "passwordtest" = {
                realm = "shadow";
                email = "passwordtest@robitzs.ch";
                firstName = "Password";
                lastName = "Test";
                enabled = true;
                emailVerified = true;
                initialPassword = "PasswordTest123!";
                temporary = true;
              };
              "securetest" = {
                realm = "shadow";
                email = "securetest@robitzs.ch";
                firstName = "Secure";
                lastName = "Final";
                enabled = true;
                emailVerified = true;
                initialPassword = "SecureFinal999!";
                temporary = true;
              };
              "finaltest" = {
                realm = "production";
                email = "finaltest@robitzs.ch";
                firstName = "Final";
                lastName = "Verification";
                enabled = false; # Changed: disable user to test update
                emailVerified = false; # Changed: test attribute change
                initialPassword = "FinalTest789!";
                temporary = true;
              };
              "abstractiontest" = {
                realm = "shadow";
                email = "abstractiontest@robitzs.ch";
                firstName = "Abstraction";
                lastName = "Test";
                enabled = true;
                emailVerified = true;
                initialPassword = "AbstractionTest999!";
                temporary = true;
              };
              "terranixtest" = {
                realm = "development";
                email = "terranixtest@robitzs.ch";
                firstName = "Terranix";
                lastName = "Enhanced";
                enabled = true;
                emailVerified = true;
                initialPassword = "TerranixTest123!";
                temporary = true;
              };
              "librarytest" = {
                realm = "development";
                email = "librarytest@robitzs.ch";
                firstName = "Updated Library";
                lastName = "Testing User";
                enabled = true;
                emailVerified = false;
                initialPassword = "UpdatedLibraryTest456!";
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
