# Example configuration demonstrating the new Keycloak Terranix module
{
  # Enable the Keycloak terranix module
  services.keycloak = {
    enable = true;

    # Provider configuration
    provider = {
      url = "http://localhost:8080";
      username = "admin";
      password = "\${var.keycloak_admin_password}";
      clientId = "admin-cli";
      clientTimeout = 60;
      initialLogin = false;
      tlsInsecureSkipVerify = true; # Only for development
    };

    # Global settings
    settings = {
      resourcePrefix = ""; # Optional prefix for terraform resource names
      validation = {
        enableCrossResourceValidation = true;
        strictMode = false;
      };
    };

    # Define variables for sensitive data
    variables = {
      keycloak_admin_password = {
        description = "Keycloak admin password";
        type = "string";
        sensitive = true;
      };
      user_default_password = {
        description = "Default password for new users";
        type = "string";
        sensitive = true;
      };
      smtp_password = {
        description = "SMTP server password";
        type = "string";
        sensitive = true;
      };
    };

    # Create realms
    realms = {
      "company" = {
        realm = "company";
        displayName = "Company Identity Realm";
        enabled = true;

        # Registration and authentication settings
        registrationAllowed = true;
        loginWithEmailAllowed = true;
        verifyEmail = true;
        resetPasswordAllowed = true;
        rememberMe = true;

        # Security settings
        passwordPolicy = "length(8) and digits(2) and lowerCase(2) and upperCase(2) and specialChars(1)";
        bruteForceProtected = true;
        failureFactor = 5;
        maxFailureWaitSeconds = 900;

        # Session settings
        ssoSessionIdleTimeout = "30m";
        ssoSessionMaxLifespan = "10h";

        # Internationalization
        internationalization = {
          enabled = true;
          supportedLocales = [
            "en"
            "de"
            "fr"
            "es"
          ];
          defaultLocale = "en";
        };

        # SMTP configuration for email sending
        smtpServer = {
          host = "smtp.company.com";
          port = 587;
          from = "noreply@company.com";
          fromDisplayName = "Company Auth";
          starttls = true;
          auth = true;
          user = "noreply@company.com";
          password = "\${var.smtp_password}";
        };

        # Custom attributes
        attributes = {
          "organization" = "Company Inc.";
          "environment" = "production";
        };
      };

      "development" = {
        realm = "development";
        displayName = "Development Environment";
        enabled = true;
        registrationAllowed = true;
        loginWithEmailAllowed = true;
        resetPasswordAllowed = true;
        bruteForceProtected = false; # Less strict for development
        ssoSessionIdleTimeout = "2h"; # Longer sessions for development
      };
    };

    # Create client scopes for fine-grained access control
    clientScopes = {
      "company-profile" = {
        name = "company-profile";
        realmId = "company";
        description = "Company-specific user profile information";
        consentScreenText = "Access to your company profile and department information";
        protocolMappers = [
          {
            name = "department";
            protocolMapper = "oidc-usermodel-attribute-mapper";
            config = {
              "user.attribute" = "department";
              "claim.name" = "department";
              "jsonType.label" = "String";
              "id.token.claim" = "true";
              "access.token.claim" = "true";
              "userinfo.token.claim" = "true";
            };
          }
          {
            name = "employee_id";
            protocolMapper = "oidc-usermodel-attribute-mapper";
            config = {
              "user.attribute" = "employee_id";
              "claim.name" = "employee_id";
              "jsonType.label" = "String";
              "id.token.claim" = "false";
              "access.token.claim" = "true";
              "userinfo.token.claim" = "true";
            };
          }
        ];
      };

      "api-access" = {
        name = "api-access";
        realmId = "company";
        description = "API access for backend services";
        displayOnConsentScreen = false;
        protocolMappers = [
          {
            name = "api-audience";
            protocolMapper = "oidc-audience-mapper";
            config = {
              "included.client.audience" = "api-gateway";
              "id.token.claim" = "false";
              "access.token.claim" = "true";
            };
          }
        ];
      };
    };

    # Create clients for different applications
    clients = {
      "web-app" = {
        clientId = "web-application";
        realmId = "company";
        name = "Company Web Application";
        description = "Main company web application";
        accessType = "CONFIDENTIAL";

        # OAuth 2.0 flows
        standardFlowEnabled = true;
        implicitFlowEnabled = false;
        directAccessGrantsEnabled = false;
        serviceAccountsEnabled = false;

        # PKCE for additional security
        pkceCodeChallengeMethod = "S256";

        # URLs
        validRedirectUris = [
          "https://app.company.com/*"
          "https://app.company.com/auth/callback"
          "http://localhost:3000/*" # Development
        ];
        validPostLogoutRedirectUris = [
          "https://app.company.com/logout"
          "http://localhost:3000/logout"
        ];
        webOrigins = [
          "https://app.company.com"
          "http://localhost:3000"
        ];

        # Client scopes
        defaultClientScopes = [
          "openid"
          "profile"
          "email"
          "company-profile"
        ];
        optionalClientScopes = [
          "phone"
          "address"
        ];

        # Session settings
        accessTokenLifespan = "5m";
        clientSessionIdleTimeout = "30m";
        clientSessionMaxLifespan = "12h";
      };

      "mobile-app" = {
        clientId = "mobile-application";
        realmId = "company";
        name = "Company Mobile App";
        accessType = "PUBLIC"; # Mobile apps can't securely store secrets

        standardFlowEnabled = true;
        pkceCodeChallengeMethod = "S256"; # Required for public clients

        validRedirectUris = [ "com.company.app://oauth/callback" ];
        defaultClientScopes = [
          "openid"
          "profile"
          "email"
        ];
      };

      "api-gateway" = {
        clientId = "api-gateway";
        realmId = "company";
        name = "API Gateway Service";
        accessType = "CONFIDENTIAL";

        # Enable service account for machine-to-machine communication
        serviceAccountsEnabled = true;
        standardFlowEnabled = false;
        implicitFlowEnabled = false;
        directAccessGrantsEnabled = false;

        defaultClientScopes = [ "api-access" ];
      };

      "dev-client" = {
        clientId = "development-client";
        realmId = "development";
        name = "Development Testing Client";
        accessType = "PUBLIC";

        standardFlowEnabled = true;
        directAccessGrantsEnabled = true; # Allow for development/testing
        pkceCodeChallengeMethod = "S256";

        validRedirectUris = [
          "http://localhost:*"
          "https://dev.company.com/*"
        ];
      };
    };

    # Create roles for authorization
    roles = {
      # Realm roles (global within the realm)
      "admin" = {
        name = "admin";
        realmId = "company";
        description = "Administrator with full system access";
        attributes = {
          permissions = [
            "full_access"
            "user_management"
            "system_config"
          ];
          level = [ "admin" ];
        };
      };

      "user" = {
        name = "user";
        realmId = "company";
        description = "Standard user role";
        attributes = {
          permissions = [ "basic_access" ];
          level = [ "user" ];
        };
      };

      "developer" = {
        name = "developer";
        realmId = "company";
        description = "Developer with elevated permissions";
        compositeRoles = {
          realmRoles = [ "user" ]; # Developers inherit user permissions
        };
        attributes = {
          permissions = [
            "dev_access"
            "api_access"
            "debug_access"
          ];
          level = [ "developer" ];
        };
      };

      "manager" = {
        name = "manager";
        realmId = "company";
        description = "Manager with team oversight permissions";
        compositeRoles = {
          realmRoles = [ "user" ];
        };
        attributes = {
          permissions = [
            "team_management"
            "reports_access"
          ];
          level = [ "manager" ];
        };
      };

      # Client-specific roles
      "web-admin" = {
        name = "admin";
        realmId = "company";
        clientId = "web-app";
        description = "Web application administrator";
        attributes = {
          app_permissions = [
            "admin_panel"
            "user_management"
            "content_management"
          ];
        };
      };

      "web-editor" = {
        name = "editor";
        realmId = "company";
        clientId = "web-app";
        description = "Web application content editor";
        attributes = {
          app_permissions = [
            "content_edit"
            "content_publish"
          ];
        };
      };

      "web-viewer" = {
        name = "viewer";
        realmId = "company";
        clientId = "web-app";
        description = "Web application viewer";
        attributes = {
          app_permissions = [ "content_view" ];
        };
      };

      # API roles with composites
      "api-admin" = {
        name = "admin";
        realmId = "company";
        clientId = "api-gateway";
        description = "API full administrative access";
        compositeRoles = {
          clientRoles = {
            "api-gateway" = [
              "read"
              "write"
            ];
          };
        };
        attributes = {
          api_permissions = [ "admin" ];
        };
      };

      "api-write" = {
        name = "write";
        realmId = "company";
        clientId = "api-gateway";
        description = "API write access";
        compositeRoles = {
          clientRoles = {
            "api-gateway" = [ "read" ];
          };
        };
        attributes = {
          api_permissions = [ "write" ];
        };
      };

      "api-read" = {
        name = "read";
        realmId = "company";
        clientId = "api-gateway";
        description = "API read access";
        attributes = {
          api_permissions = [ "read" ];
        };
      };
    };

    # Create groups for role management
    groups = {
      "employees" = {
        name = "employees";
        realmId = "company";
        realmRoles = [ "user" ];
        defaultGroup = true; # All new users automatically join this group
        attributes = {
          organization = [ "Company Inc." ];
          group_type = [ "base" ];
        };
      };

      "administrators" = {
        name = "administrators";
        realmId = "company";
        parentGroup = "employees";
        realmRoles = [ "admin" ];
        clientRoles = {
          "web-app" = [ "admin" ];
          "api-gateway" = [ "admin" ];
        };
        attributes = {
          department = [ "it" ];
          access_level = [ "admin" ];
          clearance = [ "high" ];
        };
      };

      "developers" = {
        name = "developers";
        realmId = "company";
        parentGroup = "employees";
        realmRoles = [ "developer" ];
        clientRoles = {
          "web-app" = [ "editor" ];
          "api-gateway" = [ "write" ];
        };
        attributes = {
          department = [ "engineering" ];
          access_level = [ "developer" ];
        };
      };

      "managers" = {
        name = "managers";
        realmId = "company";
        parentGroup = "employees";
        realmRoles = [ "manager" ];
        clientRoles = {
          "web-app" = [ "admin" ];
          "api-gateway" = [ "read" ];
        };
        attributes = {
          access_level = [ "manager" ];
          reports_access = [ "team" ];
        };
      };

      "content-editors" = {
        name = "content-editors";
        realmId = "company";
        parentGroup = "employees";
        clientRoles = {
          "web-app" = [ "editor" ];
        };
        attributes = {
          department = [
            "marketing"
            "content"
          ];
          access_level = [ "editor" ];
        };
      };
    };

    # Create users with various configurations
    users = {
      "system-admin" = {
        username = "admin";
        realmId = "company";
        email = "admin@company.com";
        emailVerified = true;
        firstName = "System";
        lastName = "Administrator";
        initialPassword = {
          value = "\${var.user_default_password}";
          temporary = true;
        };
        groups = [ "administrators" ];
        attributes = {
          department = [ "it" ];
          employee_id = [ "EMP-0001" ];
          hire_date = [ "2020-01-01" ];
        };
      };

      "john-developer" = {
        username = "john.doe";
        realmId = "company";
        email = "john.doe@company.com";
        emailVerified = true;
        firstName = "John";
        lastName = "Doe";
        groups = [ "developers" ];
        attributes = {
          department = [ "engineering" ];
          team = [
            "backend"
            "platform"
          ];
          employee_id = [ "EMP-1001" ];
          skills = [
            "rust"
            "nix"
            "kubernetes"
          ];
        };
      };

      "jane-manager" = {
        username = "jane.smith";
        realmId = "company";
        email = "jane.smith@company.com";
        emailVerified = true;
        firstName = "Jane";
        lastName = "Smith";
        groups = [ "managers" ];
        attributes = {
          department = [ "engineering" ];
          employee_id = [ "EMP-2001" ];
          team_size = [ "15" ];
        };
      };

      "bob-editor" = {
        username = "bob.wilson";
        realmId = "company";
        email = "bob.wilson@company.com";
        emailVerified = true;
        firstName = "Bob";
        lastName = "Wilson";
        groups = [ "content-editors" ];
        attributes = {
          department = [ "marketing" ];
          employee_id = [ "EMP-3001" ];
          specialization = [
            "technical-writing"
            "documentation"
          ];
        };
      };

      "dev-user" = {
        username = "developer";
        realmId = "development";
        email = "dev@company.com";
        emailVerified = true;
        firstName = "Development";
        lastName = "User";
        initialPassword = {
          value = "dev-password-123";
          temporary = false;
        };
      };
    };

    # Define outputs to access important resource attributes
    outputs = {
      company_realm_id = {
        value = "\${keycloak_realm.company.id}";
        description = "Company realm ID";
      };

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

      api_gateway_client_secret = {
        value = "\${keycloak_openid_client.api-gateway.client_secret}";
        description = "API gateway client secret";
        sensitive = true;
      };

      development_realm_id = {
        value = "\${keycloak_realm.development.id}";
        description = "Development realm ID";
      };

      users_summary = {
        value = builtins.toJSON {
          total_users = 5;
          realms = {
            company = 4;
            development = 1;
          };
        };
        description = "Summary of created users by realm";
      };
    };
  };
}
