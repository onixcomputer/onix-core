{ lib, config, ... }:

{
  # Keycloak Terraform Provider Configuration
  # This module handles the Terraform provider setup for Keycloak

  config = lib.mkIf config.keycloak.terraform.enable {
    keycloak.terraform = {
      # Terraform configuration block
      terraform = {
        required_providers = {
          keycloak = {
            source = "registry.opentofu.org/mrparkers/keycloak";
            version = "~> 4.0";
          };
        };
        required_version = ">= 1.0.0";
      };

      # Variable definitions for provider authentication
      variables = {
        keycloak_url = {
          description = "Keycloak server URL";
          type = "string";
          default = config.keycloak.terraform.provider.url;
        };

        keycloak_realm = {
          description = "Keycloak realm for provider authentication";
          type = "string";
          default = config.keycloak.terraform.provider.realm;
        };

        keycloak_admin_username = {
          description = "Keycloak admin username";
          type = "string";
          default = config.keycloak.terraform.provider.username;
        };

        keycloak_admin_password = {
          description = "Keycloak admin password";
          type = "string";
          sensitive = true;
        };

        keycloak_client_id = {
          description = "Keycloak client ID for admin-cli";
          type = "string";
          default = config.keycloak.terraform.provider.clientId;
        };

        keycloak_client_timeout = {
          description = "Client timeout in seconds";
          type = "number";
          default = config.keycloak.terraform.provider.clientTimeout;
        };

        keycloak_initial_login = {
          description = "Whether to perform initial login";
          type = "bool";
          default = config.keycloak.terraform.provider.initialLogin;
        };

        keycloak_tls_insecure_skip_verify = {
          description = "Skip TLS certificate verification";
          type = "bool";
          default = config.keycloak.terraform.provider.tlsInsecureSkipVerify;
        };
      };

      # Provider configuration
      provider = {
        keycloak = {
          # Admin CLI authentication (password grant)
          client_id = "\${var.keycloak_client_id}";
          username = "\${var.keycloak_admin_username}";
          password = "\${var.keycloak_admin_password}";
          url = "\${var.keycloak_url}";
          realm = "\${var.keycloak_realm}";
          initial_login = "\${var.keycloak_initial_login}";
          client_timeout = "\${var.keycloak_client_timeout}";
          tls_insecure_skip_verify = "\${var.keycloak_tls_insecure_skip_verify}";
        };
      };
    };
  };
}
