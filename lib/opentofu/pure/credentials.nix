# OpenTofu Credential Management Functions
#
# Pure functions for handling credential mapping, systemd LoadCredential
# configuration, and terraform.tfvars generation. These functions are
# pkgs-independent and work with nix-unit for fast testing.
{ lib }:

{
  # Generate LoadCredential entries for systemd services
  #
  # Converts credential mappings to systemd LoadCredential format for
  # secure credential injection into OpenTofu deployments.
  #
  # Type: String -> AttrSet String String -> [String]
  #
  # Example:
  #   generateLoadCredentials "myservice" { "db_password" = "database/password"; }
  #   => [ "db_password:/run/secrets/vars/myservice/database/password" ]
  generateLoadCredentials =
    generatorName: credentialMapping:
    lib.mapAttrsToList (
      tfVar: clanVar: "${tfVar}:/run/secrets/vars/${generatorName}/${clanVar}"
    ) credentialMapping;

  # Generate terraform.tfvars script content
  #
  # Creates shell script content that reads credentials from systemd
  # credential directory and generates a terraform.tfvars file with
  # the credential values.
  #
  # Type: AttrSet String String -> String -> String
  #
  # Example:
  #   generateTfvarsScript { "db_password" = "secret"; } "region = \"us-east-1\""
  #   => Script content that generates terraform.tfvars with db_password from credentials
  generateTfvarsScript = credentialMapping: extraContent: ''
    # Generate terraform.tfvars from clan vars
    cat > terraform.tfvars <<EOF
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        tfVar: _: "${tfVar} = \"$(cat \"$CREDENTIALS_DIRECTORY/${tfVar}\")\""
      ) credentialMapping
    )}
    ${extraContent}
    EOF
  '';

  # Validate credential mapping structure
  #
  # Ensures that credential mappings are non-empty attribute sets,
  # throwing an error for invalid configurations.
  #
  # Type: AttrSet String String -> AttrSet String String
  #
  # Example:
  #   validateCredentialMapping { "key" = "value"; }  # Valid, returns input
  #   validateCredentialMapping {}                    # Throws error
  validateCredentialMapping =
    mapping:
    if mapping == null then
      throw ''
        validateCredentialMapping: credentialMapping cannot be null

        The credentialMapping parameter is required for all terranix services.

        Quick fixes:
        • For services with no secrets: credentialMapping = { };
        • For services with secrets: credentialMapping = { terraform_var = "clan_var_name"; };

        Examples:
        credentialMapping = { };  # No credentials needed
        credentialMapping = {
          admin_password = "postgres_admin_password";
          api_key = "service_api_key";
        };

        How it works:
        • Keys = Terraform variable names (used in your terranix config)
        • Values = Clan variable names (stored in vars/ directory)
        • Automatically loaded via systemd LoadCredential
      ''
    else if !builtins.isAttrs mapping then
      throw ''
        validateCredentialMapping: Expected attribute set, got ${builtins.typeOf mapping}

        The credentialMapping must be an attribute set mapping terraform variables to clan variables.

        Fix: Change to attribute set syntax:
        ❌ credentialMapping = [ "password" ];
        ✅ credentialMapping = { admin_password = "postgres_password"; };

        ❌ credentialMapping = "password";
        ✅ credentialMapping = { api_key = "service_api_key"; };
      ''
    else if builtins.length (builtins.attrNames mapping) == 0 then
      mapping # Empty mapping is valid (no credentials needed)
    else
      let
        # Validate each mapping entry
        invalidEntries = lib.filterAttrs (
          tfVar: clanVar:
          !builtins.isString tfVar || !builtins.isString clanVar || tfVar == "" || clanVar == ""
        ) mapping;

        suspiciousEntries = lib.filterAttrs (
          tfVar: clanVar:
          # Detect common mistakes
          lib.hasInfix "/" clanVar
          # Paths instead of var names
          || lib.hasInfix "=" clanVar
          # Assignment syntax
          || lib.hasPrefix "$" clanVar
          # Variable syntax
          || tfVar == clanVar # Same name (often a mistake)
        ) mapping;
      in
      if invalidEntries != { } then
        throw ''
          validateCredentialMapping: Invalid credential mapping entries

          Invalid entries: ${
            lib.concatStringsSep ", " (lib.mapAttrsToList (k: v: "${k} = ${toString v}") invalidEntries)
          }

          Requirements:
          • Keys must be non-empty strings (terraform variable names)
          • Values must be non-empty strings (clan variable names)

          Fix examples:
          ❌ credentialMapping = { "" = "password"; };
          ✅ credentialMapping = { admin_password = "postgres_admin_password"; };

          ❌ credentialMapping = { api_key = null; };
          ✅ credentialMapping = { api_key = "service_api_key"; };
        ''
      else if suspiciousEntries != { } then
        throw ''
          validateCredentialMapping: Suspicious credential mapping detected

          Potentially incorrect entries: ${
            lib.concatStringsSep ", " (lib.mapAttrsToList (k: v: "${k} = ${v}") suspiciousEntries)
          }

          Common mistakes:
          • Using file paths as clan var names: api_key = "/run/secrets/api_key"
          • Using assignment syntax: password = "password=value"
          • Using variable syntax: token = "$MY_TOKEN"
          • Same name for both (often accidental): password = "password"

          Fix examples:
          ❌ credentialMapping = { api_key = "/run/secrets/vars/myservice/api_key"; };
          ✅ credentialMapping = { api_key = "myservice_api_key"; };

          ❌ credentialMapping = { password = "password"; };
          ✅ credentialMapping = { password = "postgres_admin_password"; };

          How it should work:
          • Keys = terraform var names (referenced in your .tf/.nix config)
          • Values = clan var names (files in vars/myservice/ directory)
          • System handles the /run/secrets/vars/ paths automatically
        ''
      else
        mapping;
}
