{ lib, config, ... }:

let
  inherit (lib) mkOption types;
in

{
  options = {
    opentofu.credentialMapping = mkOption {
      type = types.attrsOf (
        types.either types.str (
          types.submodule {
            options = {
              clanVarFile = mkOption {
                type = types.str;
                description = "Name of the clan var file containing the credential";
              };
              generatorName = mkOption {
                type = types.str;
                description = "Name of the clan vars generator";
              };
              optional = mkOption {
                type = types.bool;
                default = false;
                description = "Whether this credential is optional";
              };
            };
          }
        )
      );
      default = { };
      description = ''
        Mapping of terraform variable names to clan vars files.

        Simple form: "terraform_var_name" = "clan_var_file_name"

        Advanced form: "terraform_var_name" = {
          clanVarFile = "clan_var_file_name";
          generatorName = "custom-generator";
          optional = false;
        }

        When using simple form, the generator name defaults to the service instance name.
      '';
      example = {
        "database_password" = "db_password";
        "admin_token" = {
          clanVarFile = "admin_token";
          generatorName = "custom-auth";
          optional = false;
        };
        "api_key" = "api_secret";
      };
    };

    opentofu.additionalCredentials = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional LoadCredential entries for systemd services";
      example = [
        "custom_secret:/path/to/secret"
        "another_file:/var/lib/service/file"
      ];
    };

    opentofu.tfvarsTemplate = mkOption {
      type = types.lines;
      default = "";
      description = "Additional terraform.tfvars content template";
      example = ''
        custom_variable = "hardcoded_value"
        another_var = "$${SOME_ENV_VAR}"
      '';
    };
  };

  config = lib.mkIf (config.opentofu.credentialMapping != { }) {
    # This module provides helper functions and doesn't directly configure anything
    # The actual configuration is done by services that use this library
  };
}
