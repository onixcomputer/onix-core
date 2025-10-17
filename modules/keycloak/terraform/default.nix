{ lib, config, ... }:
let
  inherit (lib) mkOption mkEnableOption;
  inherit (lib.types)
    str
    attrsOf
    anything
    bool
    ;
in
{
  # Terraform module for Keycloak resources
  # This module provides a declarative way to manage Keycloak resources
  # including realms, clients, users, groups, and roles

  imports = [
    ./provider.nix
    ./realms.nix
    ./clients.nix
    ./users.nix
    ./groups.nix
    ./roles.nix
  ];

  options = {
    keycloak.terraform = {
      enable = mkEnableOption "Keycloak Terraform resource management";

      instanceName = mkOption {
        type = str;
        description = "Name of the Keycloak instance";
      };

      domain = mkOption {
        type = str;
        description = "Domain name for the Keycloak instance";
        example = "auth.company.com";
      };

      adminPassword = mkOption {
        type = str;
        description = "Admin password for Keycloak authentication";
        default = "";
      };

      workingDirectory = mkOption {
        type = str;
        description = "Working directory for Terraform files";
        default = "/var/lib/keycloak-terraform";
      };

      # Provider configuration
      provider = {
        url = mkOption {
          type = str;
          description = "Keycloak server URL";
        };

        realm = mkOption {
          type = str;
          default = "master";
          description = "Keycloak realm for provider authentication";
        };

        clientId = mkOption {
          type = str;
          default = "admin-cli";
          description = "Keycloak client ID for admin-cli";
        };

        username = mkOption {
          type = str;
          default = "admin";
          description = "Keycloak admin username";
        };

        clientTimeout = mkOption {
          type = lib.types.int;
          default = 60;
          description = "Client timeout in seconds";
        };

        initialLogin = mkOption {
          type = bool;
          default = false;
          description = "Whether to perform initial login";
        };

        tlsInsecureSkipVerify = mkOption {
          type = bool;
          default = false;
          description = "Skip TLS certificate verification";
        };
      };

      # Resource configurations
      realms = mkOption {
        type = attrsOf anything;
        default = { };
        description = "Keycloak realms configuration";
      };

      clients = mkOption {
        type = attrsOf anything;
        default = { };
        description = "Keycloak OIDC clients configuration";
      };

      users = mkOption {
        type = attrsOf anything;
        default = { };
        description = "Keycloak users configuration";
      };

      groups = mkOption {
        type = attrsOf anything;
        default = { };
        description = "Keycloak groups configuration";
      };

      roles = mkOption {
        type = attrsOf anything;
        default = { };
        description = "Keycloak roles configuration";
      };

      # Output configuration
      outputs = mkOption {
        type = attrsOf anything;
        default = { };
        description = "Terraform outputs for the Keycloak instance";
      };
    };
  };

  config = lib.mkIf config.keycloak.terraform.enable {
    # Configure default outputs
    keycloak.terraform.outputs = lib.mkDefault {
      keycloak_instance_info = {
        value = {
          url = config.keycloak.terraform.provider.url;
          admin_console = "${config.keycloak.terraform.provider.url}/admin";
          instance_name = config.keycloak.terraform.instanceName;
          realms = lib.mapAttrs (name: _: "\${keycloak_realm.${name}.id}") config.keycloak.terraform.realms;
          clients = lib.mapAttrs (
            name: _: "\${keycloak_openid_client.${name}.id}"
          ) config.keycloak.terraform.clients;
        };
        description = "Keycloak instance information for ${config.keycloak.terraform.instanceName}";
      };
    };
  };
}
