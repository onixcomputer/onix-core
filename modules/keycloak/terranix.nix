# Terranix module for Keycloak resource management
# Provides terraform configuration for Keycloak realms, clients, users, groups, and roles

{ lib, settings }:

let
  inherit (lib) mapAttrs;

  # Helper function to generate realm resources
  generateRealms = realms: {
    keycloak_realm = mapAttrs (name: config: {
      realm = name;
      enabled = config.enabled or true;
      display_name = config.displayName or name;
      login_with_email_allowed = config.loginWithEmailAllowed or false;
      registration_allowed = config.registrationAllowed or false;
      verify_email = config.verifyEmail or false;
      ssl_required = config.sslRequired or "external";
      password_policy = config.passwordPolicy or null;
    }) realms;
  };

  # Helper function to generate client resources
  generateClients = clients: {
    keycloak_openid_client = mapAttrs (name: config: {
      realm_id = "\${keycloak_realm.${config.realm}.id}";
      client_id = name;
      name = config.name or name;
      access_type = config.accessType or "CONFIDENTIAL";
      standard_flow_enabled = config.standardFlowEnabled or true;
      direct_access_grants_enabled = config.directAccessGrantsEnabled or false;
      service_accounts_enabled = config.serviceAccountsEnabled or false;
      valid_redirect_uris = config.validRedirectUris or [ ];
      web_origins = config.webOrigins or [ ];
    }) clients;
  };

  # Helper function to generate user resources
  generateUsers = users: {
    keycloak_user = mapAttrs (name: config: {
      realm_id = "\${keycloak_realm.${config.realm}.id}";
      username = name;
      inherit (config) email enabled;
      first_name = config.firstName;
      last_name = config.lastName;
      email_verified = config.emailVerified;
      initial_password = {
        value = config.initialPassword;
        temporary = config.temporary or true;
      };
    }) users;
  };

  # Helper function to generate group resources
  generateGroups = groups: {
    keycloak_group = mapAttrs (name: config: {
      realm_id = "\${keycloak_realm.${config.realm}.id}";
      inherit name;
      parent_id =
        if config.parentGroup != null then "\${keycloak_group.${config.parentGroup}.id}" else null;
      attributes = config.attributes or { };
    }) groups;
  };

  # Helper function to generate role resources
  generateRoles = roles: {
    keycloak_role = mapAttrs (
      name: config:
      {
        realm_id = "\${keycloak_realm.${config.realm}.id}";
        inherit name;
        description = config.description or "";
      }
      // (
        if config.client != null then
          {
            client_id = "\${keycloak_openid_client.${config.client}.id}";
          }
        else
          { }
      )
    ) roles;
  };

in
{
  # Terraform configuration
  terraform = {
    required_providers = {
      keycloak = {
        source = "mrparkers/keycloak";
        version = "~> 4.4";
      };
    };
  };

  # Provider configuration - use fixed values like original terranix-config.nix
  provider = {
    keycloak = {
      client_id = "admin-cli";
      username = "admin";
      password = "\${var.admin_password}";
      url = "http://localhost:8080";
      realm = "master";
      initial_login = false;
      client_timeout = 300;
      tls_insecure_skip_verify = true;
    };
  };

  # Variables - simplified like original
  variable = {
    admin_password = {
      description = "Keycloak admin password from clan vars";
      type = "string";
      sensitive = true;
    };
  };

  # Resources - properly merge resource types without conflicts
  resource =
    let
      realmResources = if (settings.realms or { } != { }) then (generateRealms settings.realms) else { };
      clientResources =
        if (settings.clients or { } != { }) then (generateClients settings.clients) else { };
      userResources = if (settings.users or { } != { }) then (generateUsers settings.users) else { };
      groupResources = if (settings.groups or { } != { }) then (generateGroups settings.groups) else { };
      roleResources = if (settings.roles or { } != { }) then (generateRoles settings.roles) else { };
    in
    realmResources // clientResources // userResources // groupResources // roleResources;
}
