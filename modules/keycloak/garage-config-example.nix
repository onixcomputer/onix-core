# Example Garage Configuration for Keycloak-Terraform Integration
# This provides a complete example of how to configure Garage with the systemd orchestration

_:

{
  # Example garage configuration content
  garageConfigExample = ''
    # Garage Configuration for Terraform Backend
    metadata_dir = "/var/lib/garage/meta"
    data_dir = "/var/lib/garage/data"

    replication_mode = "1"

    rpc_bind_addr = "127.0.0.1:3901"
    rpc_public_addr = "127.0.0.1:3901"
    rpc_secret = "your-secret-key-here"  # Should be generated via clan vars

    s3_region = "garage"
    api_bind_addr = "0.0.0.0:3900"
    web_bind_addr = "0.0.0.0:3902"

    admin_api_bind_addr = "127.0.0.1:3903"
    admin_api_bearer_token = "your-admin-token-here"  # Should be generated via clan vars

    # Logging
    [logger]
    level = "info"
    format = "json"

    # Database backends
    [database]
    engine = "lmdb"

    # Advanced configuration
    [compression]
    level = 3

    [performance]
    block_size = 1048576
    rebalance_max_retry = 10
  '';

  # Terraform backend configuration template
  terraformBackendConfig = ''
    terraform {
      backend "s3" {
        # These will be provided via init command line args
        # endpoint = "http://localhost:3900"
        # bucket = "keycloak-terraform-state"
        # key = "keycloak/terraform.tfstate"
        # region = "garage"

        skip_region_validation = true
        skip_credentials_validation = true
        skip_metadata_api_check = true
        force_path_style = true
      }
    }

    # Variables for Keycloak provider
    variable "keycloak_admin_password" {
      type = string
      sensitive = true
      description = "Admin password for Keycloak authentication"
    }

    variable "keycloak_url" {
      type = string
      default = "http://localhost:8080/auth"
      description = "Keycloak server URL"
    }

    # Keycloak provider configuration
    provider "keycloak" {
      client_id = "admin-cli"
      username  = "admin"
      password  = var.keycloak_admin_password
      url       = var.keycloak_url
      realm     = "master"

      # For development/testing environments
      tls_insecure_skip_verify = true
      initial_login            = false
      client_timeout           = 60
    }

    # Example resource configuration
    resource "keycloak_realm" "production" {
      realm        = "production"
      enabled      = true
      display_name = "Production Environment"

      login_with_email_allowed = true
      registration_allowed     = false
      verify_email            = true

      ssl_required = "external"
      password_policy = "upperCase(1) and lowerCase(1) and length(12) and notUsername"

      sso_session_idle_timeout    = "30m"
      sso_session_max_lifespan    = "10h"
      offline_session_idle_timeout = "720h"
      offline_session_max_lifespan = "8760h"
    }
  '';

  # Complete usage example integrating with the keycloak service
  exampleServiceConfig = {
    services.garage-terraform = {
      enable = true;

      # Garage configuration using clan vars for secrets
      garageConfig = ''
        metadata_dir = "/var/lib/garage/meta"
        data_dir = "/var/lib/garage/data"

        replication_mode = "1"

        rpc_bind_addr = "127.0.0.1:3901"
        rpc_public_addr = "127.0.0.1:3901"
        # This should reference a clan var in real usage:
        # rpc_secret = "''${config.clan.core.vars.generators.garage.files.rpc_secret.path}"

        s3_region = "garage"
        api_bind_addr = "0.0.0.0:3900"
        web_bind_addr = "0.0.0.0:3902"

        admin_api_bind_addr = "127.0.0.1:3903"
        # This should reference a clan var in real usage:
        # admin_api_bearer_token = "''${config.clan.core.vars.generators.garage.files.admin_token.path}"

        [logger]
        level = "info"
        format = "json"

        [database]
        engine = "lmdb"

        [compression]
        level = 3
      '';
    };

    # Clan vars for Garage secrets
    clan.core.vars.generators.garage = {
      files = {
        rpc_secret = { };
        admin_token = { };
      };
      runtimeInputs = [ "pkgs.pwgen" ];
      script = ''
        # Generate RPC secret (64 character hex)
        ${pkgs.pwgen}/bin/pwgen -s 64 1 | tr -d '\n' > "$out"/rpc_secret

        # Generate admin bearer token
        ${pkgs.pwgen}/bin/pwgen -s 32 1 | tr -d '\n' > "$out"/admin_token
      '';
    };
  };
}
