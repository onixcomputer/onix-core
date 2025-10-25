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
    if builtins.isAttrs mapping && mapping != { } then
      mapping
    else
      throw "validateCredentialMapping: Mapping must be a non-empty attribute set";
}
