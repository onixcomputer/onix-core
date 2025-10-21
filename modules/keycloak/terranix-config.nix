# Terranix configuration for Keycloak terraform resources
{ lib, settings }:

let
  # Helper to generate realm resources
  generateRealm = name: config: {
    keycloak_realm.${name} = {
      realm = name;
      enabled = config.enabled or true;
      display_name = config.displayName or name;
      display_name_html = config.displayNameHtml or config.displayName or name;

      login_with_email_allowed = config.loginWithEmailAllowed or false;
      duplicate_emails_allowed = config.duplicateEmailsAllowed or false;
      verify_email = config.verifyEmail or false;
      registration_allowed = config.registrationAllowed or false;
      registration_email_as_username = config.registrationEmailAsUsername or false;
      reset_password_allowed = config.resetPasswordAllowed or false;
      remember_me = config.rememberMe or false;

      ssl_required = config.sslRequired or "external";
      password_policy = config.passwordPolicy or null;

      sso_session_idle_timeout = config.ssoSessionIdleTimeout or "30m";
      sso_session_max_lifespan = config.ssoSessionMaxLifespan or "10h";
      offline_session_idle_timeout = config.offlineSessionIdleTimeout or "720h";
      offline_session_max_lifespan = config.offlineSessionMaxLifespan or "8760h";

      login_theme = config.loginTheme or "base";
      admin_theme = config.adminTheme or "base";
      account_theme = config.accountTheme or "base";
      email_theme = config.emailTheme or "base";

      internationalization =
        if config ? internationalization then
          {
            enabled = true;
            supported_locales = config.internationalization.supportedLocales or [ "en" ];
            default_locale = config.internationalization.defaultLocale or "en";
          }
        else
          null;
    };
  };

  # Helper to generate client resources
  generateClient = name: config: {
    keycloak_openid_client.${name} = lib.filterAttrs (_: v: v != null) {
      realm_id = "\${keycloak_realm.${config.realm}.id}";
      client_id = name;
      name = config.name or name;
      description = config.description or null;

      access_type = config.accessType or "PUBLIC";
      standard_flow_enabled = config.standardFlowEnabled or true;
      implicit_flow_enabled = config.implicitFlowEnabled or false;
      direct_access_grants_enabled = config.directAccessGrantsEnabled or false;
      service_accounts_enabled = config.serviceAccountsEnabled or false;

      valid_redirect_uris = config.validRedirectUris or [ ];
      valid_post_logout_redirect_uris = config.validPostLogoutRedirectUris or [ ];
      web_origins = config.webOrigins or [ ];

      pkce_code_challenge_method = config.pkceCodeChallengeMethod or null;
    };
  };

  # Helper to generate user resources
  generateUser = name: config: {
    keycloak_user.${name} = {
      realm_id = "\${keycloak_realm.${config.realm}.id}";
      username = name;
      email = config.email or null;
      first_name = config.firstName or null;
      last_name = config.lastName or null;
      enabled = config.enabled or true;
      email_verified = config.emailVerified or false;
      attributes = config.attributes or null;

      initial_password =
        if config ? initialPassword then
          {
            value = config.initialPassword;
            temporary = config.temporary or true;
          }
        else
          null;
    };
  };

  # Helper to generate group resources
  generateGroup = name: config: {
    keycloak_group.${name} = lib.filterAttrs (_: v: v != null) {
      realm_id = "\${keycloak_realm.${config.realm}.id}";
      inherit name;
      parent_id =
        if config.parentGroup or null != null then "\${keycloak_group.${config.parentGroup}.id}" else null;
      attributes = config.attributes or null;
    };
  };

  # Helper to generate role resources
  generateRole =
    name: config:
    if config.client or null != null then
      {
        keycloak_role.${name} = {
          realm_id = "\${keycloak_realm.${config.realm}.id}";
          client_id = "\${keycloak_openid_client.${config.client}.id}";
          inherit name;
          description = config.description or null;
        };
      }
    else
      {
        keycloak_role.${name} = {
          realm_id = "\${keycloak_realm.${config.realm}.id}";
          inherit name;
          description = config.description or null;
        };
      };

  # Admin user password management is handled by keycloak-admin-password-sync service
  # Terraform cannot manage existing admin user password - only authentication
  adminUserResource = { };

  # Merge all resource generators
  resources = lib.foldl' lib.recursiveUpdate { } [
    # Add admin user management
    adminUserResource

    # Generate all realms
    (lib.foldl' lib.recursiveUpdate { } (
      lib.mapAttrsToList generateRealm (settings.terraform.realms or { })
    ))

    # Generate all clients
    (lib.foldl' lib.recursiveUpdate { } (
      lib.mapAttrsToList generateClient (settings.terraform.clients or { })
    ))

    # Generate all users
    (lib.foldl' lib.recursiveUpdate { } (
      lib.mapAttrsToList generateUser (settings.terraform.users or { })
    ))

    # Generate all groups
    (lib.foldl' lib.recursiveUpdate { } (
      lib.mapAttrsToList generateGroup (settings.terraform.groups or { })
    ))

    # Generate all roles
    (lib.foldl' lib.recursiveUpdate { } (
      lib.mapAttrsToList generateRole (settings.terraform.roles or { })
    ))
  ];

in
{
  # Terraform configuration
  terraform = {
    required_providers = {
      keycloak = {
        source = "registry.opentofu.org/mrparkers/keycloak";
        version = "~> 4.4";
      };
    };
    required_version = ">= 1.0.0";
  };

  # Variables for admin password from clan vars
  variable = {
    admin_password = {
      description = "Keycloak admin password from clan vars";
      type = "string";
      sensitive = true;
    };
  };

  # Provider configuration
  provider.keycloak = {
    client_id = "admin-cli";
    username = "admin";
    password = "\${var.admin_password}";
    url = "http://localhost:8080";
    realm = "master";
    initial_login = false; # Critical: Avoid auth during plan phase
    client_timeout = 300; # Increased timeout
    tls_insecure_skip_verify = true;
  };

  # Resources
  resource = resources;

  # Outputs
  output = {
    realms = {
      value = lib.mapAttrs (name: _: "\${keycloak_realm.${name}.id}") (settings.terraform.realms or { });
      description = "Created realm IDs";
    };

    clients = {
      value = lib.mapAttrs (name: _: "\${keycloak_openid_client.${name}.id}") (
        settings.terraform.clients or { }
      );
      description = "Created client IDs";
    };

    users = {
      value = lib.mapAttrs (name: _: "\${keycloak_user.${name}.id}") (settings.terraform.users or { });
      description = "Created user IDs";
    };

    groups = {
      value = lib.mapAttrs (name: _: "\${keycloak_group.${name}.id}") (settings.terraform.groups or { });
      description = "Created group IDs";
    };

    roles = {
      value = lib.mapAttrs (name: _: "\${keycloak_role.${name}.id}") (settings.terraform.roles or { });
      description = "Created role IDs";
    };
  };
}
