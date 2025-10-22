{ lib, ... }:

# Terraform Configuration Generator for Keycloak
# This function generates terraform configurations using the terraform module system

let

  # Generate terraform configuration using the module system
  generateTerraformConfig =
    instanceName: settings: adminPasswordFile:
    let
      # Evaluate the terraform module using lib.evalModules
      terraformModule = lib.evalModules {
        modules = [
          ./terraform/default.nix
          {
            keycloak.terraform = {
              enable = true;
              instanceName = instanceName;
              domain = settings.domain;
              adminPassword = "\${var.keycloak_admin_password}";

              # Provider settings (these are used by provider.nix)
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
          }
        ];
      };

      # Extract the generated terraform configuration
      tfConfig = terraformModule.config.keycloak.terraform;

      # Convert nix attribute sets to JSON for terraform
      toJsonString = value: builtins.toJSON value;

      # Helper function to restructure flat keys into nested structure
      # Converts "keycloak_group.administrators" into { keycloak_group = { administrators = {...} } }
      restructureResources =
        resources:
        let
          processKey =
            key: value:
            let
              parts = lib.splitString "." key;
            in
            if (builtins.length parts) == 2 then
              {
                ${builtins.elemAt parts 0} = {
                  ${builtins.elemAt parts 1} = value;
                };
              }
            else
              { ${key} = value; };

          restructured = lib.mapAttrsToList processKey resources;

          # Properly merge the nested structures without using lib.mkMerge
          mergeNested = lib.foldl' (acc: item: lib.recursiveUpdate acc item) { } restructured;
        in
        mergeNested;

      # Convert providers attrset to terraform JSON array format for aliases
      # Terraform JSON requires provider aliases to be in array format
      convertProviders =
        providers:
        let
          providerList = lib.mapAttrsToList (
            name: config:
            if lib.hasPrefix "keycloak." name then
              # This is an aliased provider (e.g., "keycloak.bootstrap")
              { keycloak = config; }
            else
              # This is the default provider or other provider type
              { ${name} = config; }
          ) providers;
        in
        if lib.length providerList > 1 then providerList else providers;

      # Generate main terraform configuration
      # Only include blocks that have content to avoid Terraform JSON errors
      mainTerraformConfig =
        let
          dataBlock = restructureResources (tfConfig.data or { });
          resourceBlock = restructureResources (tfConfig.resources or { });
        in
        {
          terraform = tfConfig.terraform or { };
          variable = tfConfig.variables or { };
          provider = convertProviders (tfConfig.providers or { });
          output = tfConfig.outputs or { };
        }
        // lib.optionalAttrs (dataBlock != { }) { data = dataBlock; }
        // lib.optionalAttrs (resourceBlock != { }) { resource = resourceBlock; };

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
