{ lib, ... }:

# Terraform Configuration Generator for Keycloak
# This function generates terraform configurations using the terraform module system

let

  # Generate terraform configuration using the module system
  generateTerraformConfig =
    instanceName: settings: adminPasswordFile:
    let
      # Configure the terraform module with settings
      terraformConfig = {
        keycloak.terraform = {
          enable = true;
          instanceName = instanceName;
          domain = settings.domain;
          adminPassword = "\${var.keycloak_admin_password}";

          # Provider configuration
          provider = {
            url = "https://${settings.domain}";
            realm = "master";
            clientId = "admin-cli";
            username = "admin";
            clientTimeout = 60;
            initialLogin = false;
            tlsInsecureSkipVerify = false;
          };

          # Merge user-defined terraform configuration
          realms = settings.terraform.realms or { };
          clients = settings.terraform.clients or { };
          users = settings.terraform.users or { };
          groups = settings.terraform.groups or { };
          roles = settings.terraform.roles or { };
        };
      };

      # Import the terraform module and evaluate it
      terraformModule = import ./terraform/default.nix {
        inherit lib;
        config = terraformConfig;
      };

      # Extract the generated terraform configuration
      tfConfig = terraformModule.config.keycloak.terraform;

      # Convert nix attribute sets to JSON for terraform
      toJsonString = value: builtins.toJSON value;

      # Generate main terraform configuration
      mainTerraformConfig = {
        terraform = tfConfig.terraform or { };
        variable = tfConfig.variables or { };
        provider = tfConfig.provider or { };
        data = tfConfig.data or { };
        resource = tfConfig.resources or { };
        output = tfConfig.outputs or { };
      };

      # Generate the complete terraform JSON configuration
      terraformJson = toJsonString mainTerraformConfig;

    in
    {
      inherit terraformJson;
      adminPasswordFile = adminPasswordFile;
      domain = settings.domain;
    };

in
{
  # Export the generator function
  inherit generateTerraformConfig;
}
