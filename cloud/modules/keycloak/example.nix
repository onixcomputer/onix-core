# Example configuration showing how to use the Keycloak terranix modules
{ ... }:
{
  imports = [
    ./default.nix
  ];

  # Configure the Keycloak provider
  services.keycloak = {
    enable = true;
    url = "https://auth.robitzs.ch:9081";
    adminUser = "admin";
    adminPassword = "admin-adeci"; # In production, use a variable or secret
    clientId = "admin-cli";
    clientTimeout = 60;
    initialLogin = false;

    # Create realms
    realms = {
      "my-company" = {
        name = "my-company";
        displayName = "My Company Realm";
        enabled = true;
        registrationAllowed = true;
        loginTheme = "base";
        verifyEmail = true;
        loginWithEmailAllowed = true;
        resetPasswordAllowed = true;
        rememberMe = true;
        bruteForceProtected = true;
        failureFactor = 5;
        maxFailureWaitSeconds = 900;
        internationalizationEnabled = true;
        supportedLocales = [
          "en"
          "de"
          "fr"
        ];
        defaultLocale = "en";
      };
    };

    # Create client scopes
    clientScopes = {
      "company-scope" = {
        name = "company-scope";
        realmId = "my-company";
        description = "Company-specific scope for internal applications";
        protocol = "openid-connect";
        includeInTokenScope = true;
      };
    };

    # Create clients
    clients = {
      "web-app" = {
        name = "web-app";
        realmId = "my-company";
        clientId = "web-application";
        accessType = "CONFIDENTIAL";
        standardFlowEnabled = true;
        implicitFlowEnabled = false;
        directAccessGrantsEnabled = false;
        validRedirectUris = [
          "https://app.company.com/*"
          "http://localhost:3000/*"
        ];
        validPostLogoutRedirectUris = [
          "https://app.company.com/logout"
          "http://localhost:3000/logout"
        ];
        webOrigins = [
          "https://app.company.com"
          "http://localhost:3000"
        ];
        defaultClientScopes = [
          "openid"
          "profile"
          "email"
          "company-scope"
        ];
        pkceCodeChallengeMethod = "S256";
      };

      "mobile-app" = {
        name = "mobile-app";
        realmId = "my-company";
        clientId = "mobile-application";
        accessType = "PUBLIC";
        standardFlowEnabled = true;
        implicitFlowEnabled = false;
        directAccessGrantsEnabled = false;
        pkceCodeChallengeMethod = "S256";
        validRedirectUris = [
          "com.company.app://oauth/callback"
        ];
        defaultClientScopes = [
          "openid"
          "profile"
          "email"
        ];
      };

      "api-service" = {
        name = "api-service";
        realmId = "my-company";
        clientId = "api-backend";
        accessType = "CONFIDENTIAL";
        serviceAccountsEnabled = true;
        standardFlowEnabled = false;
        implicitFlowEnabled = false;
        directAccessGrantsEnabled = false;
      };
    };

    # Create roles
    roles = {
      "admin" = {
        name = "admin";
        realmId = "my-company";
        description = "Administrator role with full access";
      };

      "user" = {
        name = "user";
        realmId = "my-company";
        description = "Standard user role";
      };

      "developer" = {
        name = "developer";
        realmId = "my-company";
        description = "Developer role with development access";
      };

      "web-app-admin" = {
        name = "admin";
        realmId = "my-company";
        clientId = "web-application";
        description = "Web application administrator";
      };

      "api-read" = {
        name = "api-read";
        realmId = "my-company";
        clientId = "api-backend";
        description = "API read access";
      };

      "api-write" = {
        name = "api-write";
        realmId = "my-company";
        clientId = "api-backend";
        description = "API write access";
      };
    };

    # Create groups
    groups = {
      "administrators" = {
        name = "administrators";
        realmId = "my-company";
        realmRoles = [ "admin" ];
        clientRoles = {
          "web-application" = [ "admin" ];
          "api-backend" = [
            "api-read"
            "api-write"
          ];
        };
      };

      "developers" = {
        name = "developers";
        realmId = "my-company";
        realmRoles = [
          "user"
          "developer"
        ];
        clientRoles = {
          "api-backend" = [
            "api-read"
            "api-write"
          ];
        };
      };

      "end-users" = {
        name = "end-users";
        realmId = "my-company";
        realmRoles = [ "user" ];
        clientRoles = {
          "api-backend" = [ "api-read" ];
        };
      };
    };

    # Create users
    users = {
      "admin-user" = {
        username = "admin";
        realmId = "my-company";
        email = "admin@company.com";
        emailVerified = true;
        firstName = "System";
        lastName = "Administrator";
        initialPassword = "changeme123!";
        temporaryPassword = true;
        groups = [ "administrators" ];
      };

      "john-developer" = {
        username = "john.doe";
        realmId = "my-company";
        email = "john.doe@company.com";
        emailVerified = true;
        firstName = "John";
        lastName = "Doe";
        groups = [ "developers" ];
        attributes = {
          department = [ "engineering" ];
          team = [ "backend" ];
        };
      };

      "jane-user" = {
        username = "jane.smith";
        realmId = "my-company";
        email = "jane.smith@company.com";
        emailVerified = true;
        firstName = "Jane";
        lastName = "Smith";
        groups = [ "end-users" ];
        attributes = {
          department = [ "marketing" ];
        };
      };
    };
  };

  # Optional: Add outputs to retrieve important information
  output = {
    # Realm information
    company_realm_id = {
      value = "\${keycloak_realm.my-company.id}";
      description = "Company realm ID";
    };

    # Client information
    web_app_client_id = {
      value = "\${keycloak_openid_client.web-app.client_id}";
      description = "Web application client ID";
    };

    web_app_client_secret = {
      value = "\${keycloak_openid_client.web-app.client_secret}";
      description = "Web application client secret";
      sensitive = true;
    };

    mobile_app_client_id = {
      value = "\${keycloak_openid_client.mobile-app.client_id}";
      description = "Mobile application client ID";
    };

    api_service_client_id = {
      value = "\${keycloak_openid_client.api-service.client_id}";
      description = "API service client ID";
    };

    api_service_client_secret = {
      value = "\${keycloak_openid_client.api-service.client_secret}";
      description = "API service client secret";
      sensitive = true;
    };

    # User information
    admin_user_id = {
      value = "\${keycloak_user.admin-user.id}";
      description = "Admin user ID";
    };
  };
}
