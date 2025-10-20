{ ... }:
{
  # Simplified Keycloak configuration for admin-cli authentication
  # This version only includes variables actually needed for admin-cli auth

  terraform = {
    required_providers = {
      keycloak = {
        source = "registry.opentofu.org/mrparkers/keycloak";
        version = "~> 4.0";
      };
    };
    required_version = ">= 1.0.0";
  };

  # Only include variables needed for admin-cli authentication
  variable = {
    keycloak_url = {
      description = "Keycloak server URL";
      type = "string";
      default = "https://auth.robitzs.ch";
    };

    keycloak_realm = {
      description = "Keycloak realm for provider authentication";
      type = "string";
      default = "master";
    };

    keycloak_admin_username = {
      description = "Keycloak admin username";
      type = "string";
      default = "admin";
    };

    keycloak_admin_password = {
      description = "Keycloak admin password";
      type = "string";
      sensitive = true;
      default = "admin-adeci";
    };

    clan_admin_password = {
      description = "Secure admin password from clan vars";
      type = "string";
      sensitive = true;
      default = "";
    };

    keycloak_client_id = {
      description = "Keycloak client ID for admin-cli";
      type = "string";
      default = "admin-cli";
    };

    keycloak_client_timeout = {
      description = "Client timeout in seconds";
      type = "number";
      default = 60;
    };

    keycloak_initial_login = {
      description = "Whether to perform initial login";
      type = "bool";
      default = false;
    };

    keycloak_tls_insecure_skip_verify = {
      description = "Skip TLS certificate verification";
      type = "bool";
      default = false;
    };
  };

  provider.keycloak = {
    # Admin CLI authentication (password grant) - no client_secret needed
    client_id = "\${var.keycloak_client_id}";
    username = "\${var.keycloak_admin_username}";
    password = "\${var.keycloak_admin_password}";
    url = "\${var.keycloak_url}";
    realm = "\${var.keycloak_realm}";
    initial_login = "\${var.keycloak_initial_login}";
    client_timeout = "\${var.keycloak_client_timeout}";
    tls_insecure_skip_verify = "\${var.keycloak_tls_insecure_skip_verify}";
  };

  resource = {
    # Example Production Realm
    keycloak_realm.production = {
      realm = "production";
      enabled = true;
      display_name = "Production Environment";
      display_name_html = "<h1>Production Environment</h1>";

      # Login settings
      login_with_email_allowed = true;
      duplicate_emails_allowed = false;
      verify_email = true;
      registration_allowed = true;
      registration_email_as_username = true;
      reset_password_allowed = true;
      remember_me = true;

      # Security settings
      ssl_required = "external";
      password_policy = "upperCase(1) and length(8) and forceExpiredPasswordChange(365) and notUsername";

      # Session settings
      sso_session_idle_timeout = "30m";
      sso_session_max_lifespan = "10h";
      offline_session_idle_timeout = "720h";
      offline_session_max_lifespan = "8760h";

      # Themes
      login_theme = "base";
      admin_theme = "base";
      account_theme = "base";
      email_theme = "base";

      # Internationalization
      internationalization = {
        supported_locales = [
          "en"
          "de"
          "fr"
        ];
        default_locale = "en";
      };
    };

    # Development Realm
    keycloak_realm.development = {
      realm = "development";
      enabled = true;
      display_name = "Development Environment";
      display_name_html = "<h1>Development Environment</h1>";

      # Relaxed settings for development
      registration_allowed = true;
      verify_email = false;
      ssl_required = "external";
      password_policy = "length(6)";
    };

    # Web Application Client
    keycloak_openid_client.web-app = {
      realm_id = "\${keycloak_realm.production.id}";
      client_id = "web-application";
      name = "Web Application";
      description = "Main web application client";

      # Security configuration
      enabled = true;
      access_type = "CONFIDENTIAL";
      standard_flow_enabled = true;
      implicit_flow_enabled = false;
      direct_access_grants_enabled = false;
      service_accounts_enabled = false;

      # URLs and redirects
      root_url = "https://app.example.com";
      admin_url = "https://app.example.com";
      base_url = "/";

      valid_redirect_uris = [
        "https://app.example.com/auth/callback"
        "https://app.example.com/oauth2/callback"
      ];

      valid_post_logout_redirect_uris = [
        "https://app.example.com/logout"
      ];

      web_origins = [
        "https://app.example.com"
      ];

      # PKCE for enhanced security
      pkce_code_challenge_method = "S256";
    };

    # Mobile Application Client
    keycloak_openid_client.mobile-app = {
      realm_id = "\${keycloak_realm.production.id}";
      client_id = "mobile-application";
      name = "Mobile Application";
      description = "Mobile application client";

      # Public client for mobile
      enabled = true;
      access_type = "PUBLIC";
      standard_flow_enabled = true;
      implicit_flow_enabled = false;
      direct_access_grants_enabled = true;

      # Mobile-specific redirects
      valid_redirect_uris = [
        "com.example.app://oauth/callback"
        "http://localhost:3000/auth/callback"
      ];

      # PKCE required for public clients
      pkce_code_challenge_method = "S256";
    };

    # API Service Client (machine-to-machine)
    keycloak_openid_client.api-service = {
      realm_id = "\${keycloak_realm.production.id}";
      client_id = "api-backend";
      name = "API Service";
      description = "Backend API service";

      # Service account client
      enabled = true;
      access_type = "CONFIDENTIAL";
      service_accounts_enabled = true;
      standard_flow_enabled = false;
      implicit_flow_enabled = false;
      direct_access_grants_enabled = false;
    };

    # Development Client
    keycloak_openid_client.dev-client = {
      realm_id = "\${keycloak_realm.development.id}";
      client_id = "development-app";
      name = "Development Client";
      description = "Development testing client";

      # Relaxed settings for development
      enabled = true;
      access_type = "PUBLIC";
      standard_flow_enabled = true;
      implicit_flow_enabled = true;
      direct_access_grants_enabled = true;

      valid_redirect_uris = [
        "http://localhost:3000/*"
        "http://localhost:8080/*"
        "http://127.0.0.1:3000/*"
      ];

      web_origins = [
        "http://localhost:3000"
        "http://localhost:8080"
        "http://127.0.0.1:3000"
      ];
    };

    # Groups
    keycloak_group.administrators = {
      realm_id = "\${keycloak_realm.production.id}";
      name = "administrators";

      attributes = {
        description = "System administrators with full access";
        level = "admin";
      };
    };

    keycloak_group.users = {
      realm_id = "\${keycloak_realm.production.id}";
      name = "users";

      attributes = {
        description = "Standard application users";
        level = "user";
      };
    };

    keycloak_group.power-users = {
      realm_id = "\${keycloak_realm.production.id}";
      parent_id = "\${keycloak_group.users.id}";
      name = "power-users";

      attributes = {
        description = "Users with enhanced permissions";
        level = "power-user";
      };
    };

    keycloak_group.developers = {
      realm_id = "\${keycloak_realm.development.id}";
      name = "developers";

      attributes = {
        description = "Development team members";
        level = "developer";
      };
    };

    # Roles
    keycloak_role.admin-role = {
      realm_id = "\${keycloak_realm.production.id}";
      name = "admin";
      description = "Administrator role with full access";
    };

    keycloak_role.user-role = {
      realm_id = "\${keycloak_realm.production.id}";
      name = "user";
      description = "Standard user role";
    };

    keycloak_role.manager-role = {
      realm_id = "\${keycloak_realm.production.id}";
      name = "manager";
      description = "Manager role with elevated permissions";
    };

    # Client-specific roles
    keycloak_role.app-admin = {
      realm_id = "\${keycloak_realm.production.id}";
      client_id = "\${keycloak_openid_client.web-app.id}";
      name = "app-admin";
      description = "Application administrator";
    };

    keycloak_role.app-user = {
      realm_id = "\${keycloak_realm.production.id}";
      client_id = "\${keycloak_openid_client.web-app.id}";
      name = "app-user";
      description = "Application user";
    };

    # Development roles
    keycloak_role.dev-role = {
      realm_id = "\${keycloak_realm.development.id}";
      name = "developer";
      description = "Developer access role";
    };

    # Bootstrap admin password upgrade (Phase 2: Security)
    keycloak_user.bootstrap_admin_upgrade = {
      realm_id = "master"; # Master realm admin user
      username = "admin"; # The bootstrap user created by NixOS
      enabled = true;
      email_verified = true;

      email = "admin@robitzs.ch";
      first_name = "Bootstrap";
      last_name = "Administrator";

      # Upgrade password to secure clan vars value
      initial_password = {
        value = "\${var.clan_admin_password}"; # Secure generated password
        temporary = false; # Keep this password permanently
      };
    };

    # Users
    keycloak_user.admin = {
      realm_id = "\${keycloak_realm.production.id}";
      username = "admin-terranix";
      enabled = true;
      email_verified = true;

      email = "admin-terranix@example.com";
      first_name = "System";
      last_name = "Administrator";

      attributes = {
        department = "IT";
        role = "administrator";
        employee_id = "EMP001";
      };

      initial_password = {
        value = "Admin123!";
        temporary = true;
      };
    };

    keycloak_user.testuser = {
      realm_id = "\${keycloak_realm.development.id}";
      username = "testuser";
      enabled = true;
      email_verified = false;

      email = "test@example.com";
      first_name = "Test";
      last_name = "User";

      attributes = {
        department = "Testing";
        role = "tester";
      };

      initial_password = {
        value = "password123";
        temporary = true;
      };
    };

    keycloak_user.appuser = {
      realm_id = "\${keycloak_realm.production.id}";
      username = "appuser-terranix";
      enabled = true;
      email_verified = true;

      email = "appuser-terranix@example.com";
      first_name = "Application";
      last_name = "User";

      attributes = {
        department = "Operations";
        role = "user";
      };

      initial_password = {
        value = "User123!";
        temporary = true;
      };
    };

    # Group memberships
    keycloak_user_groups.admin-groups = {
      realm_id = "\${keycloak_realm.production.id}";
      user_id = "\${keycloak_user.admin.id}";
      group_ids = [ "\${keycloak_group.administrators.id}" ];
    };

    keycloak_user_groups.appuser-groups = {
      realm_id = "\${keycloak_realm.production.id}";
      user_id = "\${keycloak_user.appuser.id}";
      group_ids = [ "\${keycloak_group.users.id}" ];
    };

    keycloak_user_groups.testuser-groups = {
      realm_id = "\${keycloak_realm.development.id}";
      user_id = "\${keycloak_user.testuser.id}";
      group_ids = [ "\${keycloak_group.developers.id}" ];
    };

    # Role assignments
    keycloak_user_roles.admin-roles = {
      realm_id = "\${keycloak_realm.production.id}";
      user_id = "\${keycloak_user.admin.id}";
      role_ids = [ "\${keycloak_role.admin-role.id}" ];
    };

    keycloak_user_roles.appuser-roles = {
      realm_id = "\${keycloak_realm.production.id}";
      user_id = "\${keycloak_user.appuser.id}";
      role_ids = [ "\${keycloak_role.user-role.id}" ];
    };

    keycloak_user_roles.testuser-roles = {
      realm_id = "\${keycloak_realm.development.id}";
      user_id = "\${keycloak_user.testuser.id}";
      role_ids = [ "\${keycloak_role.dev-role.id}" ];
    };

    # Group role mappings
    keycloak_group_roles.admin-group-roles = {
      realm_id = "\${keycloak_realm.production.id}";
      group_id = "\${keycloak_group.administrators.id}";
      role_ids = [ "\${keycloak_role.admin-role.id}" ];
    };

    keycloak_group_roles.user-group-roles = {
      realm_id = "\${keycloak_realm.production.id}";
      group_id = "\${keycloak_group.users.id}";
      role_ids = [ "\${keycloak_role.user-role.id}" ];
    };
  };

  output = {
    # Realm outputs
    realm_production_id = {
      value = "\${keycloak_realm.production.id}";
      description = "Production realm ID";
    };

    realm_development_id = {
      value = "\${keycloak_realm.development.id}";
      description = "Development realm ID";
    };

    # Client outputs
    client_web_app_id = {
      value = "\${keycloak_openid_client.web-app.id}";
      description = "Web application client ID";
    };

    client_web_app_secret = {
      value = "\${keycloak_openid_client.web-app.client_secret}";
      description = "Web application client secret";
      sensitive = true;
    };

    client_mobile_app_id = {
      value = "\${keycloak_openid_client.mobile-app.id}";
      description = "Mobile application client ID";
    };

    client_api_service_id = {
      value = "\${keycloak_openid_client.api-service.id}";
      description = "API service client ID";
    };

    client_api_service_secret = {
      value = "\${keycloak_openid_client.api-service.client_secret}";
      description = "API service client secret";
      sensitive = true;
    };

    # User outputs
    user_admin_id = {
      value = "\${keycloak_user.admin.id}";
      description = "Admin user ID";
    };

    user_appuser_id = {
      value = "\${keycloak_user.appuser.id}";
      description = "Application user ID";
    };

    user_testuser_id = {
      value = "\${keycloak_user.testuser.id}";
      description = "Test user ID";
    };

    # Group outputs
    group_administrators_id = {
      value = "\${keycloak_group.administrators.id}";
      description = "Administrators group ID";
    };

    group_users_id = {
      value = "\${keycloak_group.users.id}";
      description = "Users group ID";
    };

    group_developers_id = {
      value = "\${keycloak_group.developers.id}";
      description = "Developers group ID";
    };

    # Keycloak URLs
    keycloak_urls = {
      value = {
        production_realm = "\${var.keycloak_url}/realms/production";
        development_realm = "\${var.keycloak_url}/realms/development";
        admin_console = "\${var.keycloak_url}/admin";
        production_auth = "\${var.keycloak_url}/realms/production/protocol/openid_connect/auth";
        production_token = "\${var.keycloak_url}/realms/production/protocol/openid_connect/token";
        development_auth = "\${var.keycloak_url}/realms/development/protocol/openid_connect/auth";
        development_token = "\${var.keycloak_url}/realms/development/protocol/openid_connect/token";
      };
      description = "Keycloak access URLs";
    };
  };
}
