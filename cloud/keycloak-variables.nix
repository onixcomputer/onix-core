{ ... }:
{
  # Keycloak Provider Variables
  # These variables allow secure credential management for the Keycloak provider

  variable = {
    # Keycloak Server Configuration
    keycloak_url = {
      description = "Keycloak server URL (e.g., https://auth.robitzs.ch:9081)";
      type = "string";
      default = "https://auth.robitzs.ch:9081";
    };

    keycloak_realm = {
      description = "Keycloak realm for provider authentication";
      type = "string";
      default = "master";
    };

    # Authentication Configuration - Admin CLI Method (current setup)
    keycloak_admin_username = {
      description = "Keycloak admin username for provider authentication";
      type = "string";
      default = "admin";
    };

    keycloak_admin_password = {
      description = "Keycloak admin password for provider authentication (bootstrap password)";
      type = "string";
      sensitive = true;
    };

    clan_admin_password = {
      description = "Secure admin password from clan vars (for password upgrade)";
      type = "string";
      sensitive = true;
    };

    # Authentication Configuration - Client Credentials Method (recommended for production)
    keycloak_client_id = {
      description = "Keycloak client ID for Terraform provider authentication";
      type = "string";
      default = "admin-cli";
    };

    keycloak_client_secret = {
      description = "Keycloak client secret for Terraform provider authentication (when using client credentials)";
      type = "string";
      sensitive = true;
      default = null;
    };

    # Advanced Configuration
    keycloak_client_timeout = {
      description = "Timeout in seconds for Keycloak client requests";
      type = "number";
      default = 60;
    };

    keycloak_initial_login = {
      description = "Whether to perform initial login during provider setup";
      type = "bool";
      default = false;
    };

    keycloak_tls_insecure_skip_verify = {
      description = "Skip TLS certificate verification (not recommended for production)";
      type = "bool";
      default = false;
    };

    # Resource-specific variables
    keycloak_default_realm_name = {
      description = "Default realm name for Keycloak resources";
      type = "string";
      default = "production";
    };

    keycloak_default_client_secret = {
      description = "Default client secret for created OIDC clients";
      type = "string";
      sensitive = true;
      default = null;
    };

    # Email/SMTP Configuration for realms
    smtp_host = {
      description = "SMTP server host for Keycloak email";
      type = "string";
      default = null;
    };

    smtp_port = {
      description = "SMTP server port";
      type = "number";
      default = 587;
    };

    smtp_from = {
      description = "From email address for Keycloak emails";
      type = "string";
      default = null;
    };

    smtp_username = {
      description = "SMTP authentication username";
      type = "string";
      default = null;
    };

    smtp_password = {
      description = "SMTP authentication password";
      type = "string";
      sensitive = true;
      default = null;
    };
  };

  # Outputs for reference and integration
  output = {
    keycloak_provider_config = {
      description = "Keycloak provider configuration summary";
      value = {
        url = "\${var.keycloak_url}";
        realm = "\${var.keycloak_realm}";
        client_id = "\${var.keycloak_client_id}";
        timeout = "\${var.keycloak_client_timeout}";
      };
      sensitive = false;
    };

    keycloak_environment_variables = {
      description = "Environment variables for Keycloak configuration";
      value = {
        KEYCLOAK_URL = "\${var.keycloak_url}";
        KEYCLOAK_REALM = "\${var.keycloak_realm}";
        KEYCLOAK_CLIENT_ID = "\${var.keycloak_client_id}";
        KEYCLOAK_CLIENT_TIMEOUT = "\${var.keycloak_client_timeout}";
      };
      sensitive = false;
    };
  };
}
