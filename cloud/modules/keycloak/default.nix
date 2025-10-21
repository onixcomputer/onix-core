{ lib, config, ... }:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    ;
  cfg = config.services.keycloak;
in
{
  imports = [
    ./realm.nix
    ./clients.nix
    ./users.nix
  ];

  options.services.keycloak = {
    enable = mkEnableOption "Keycloak Terraform resources";

    url = mkOption {
      type = types.str;
      description = "Keycloak server URL";
      example = "https://auth.example.com";
    };

    realm = mkOption {
      type = types.str;
      default = "master";
      description = "Default realm to use for resources";
    };

    adminUser = mkOption {
      type = types.str;
      default = "admin";
      description = "Admin username for Keycloak provider";
    };

    adminPassword = mkOption {
      type = types.str;
      description = "Admin password for Keycloak provider";
    };

    clientId = mkOption {
      type = types.str;
      default = "admin-cli";
      description = "Client ID for Keycloak provider authentication";
    };

    clientTimeout = mkOption {
      type = types.int;
      default = 60;
      description = "Client timeout in seconds";
    };

    initialLogin = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to perform initial login";
    };
  };

  config = mkIf cfg.enable {
    # Configure Keycloak provider
    provider.keycloak = {
      client_id = cfg.clientId;
      username = cfg.adminUser;
      password = cfg.adminPassword;
      inherit (cfg) url;
      initial_login = cfg.initialLogin;
      client_timeout = cfg.clientTimeout;
    };

    # Add required provider to terraform configuration
    terraform.required_providers.keycloak = {
      source = "registry.opentofu.org/mrparkers/keycloak";
      version = "~> 4.0";
    };
  };
}
