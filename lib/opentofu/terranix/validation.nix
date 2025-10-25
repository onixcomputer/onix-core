# Terranix Validation Module
{ lib }:

{
  # Validate terranix configuration structure
  validateTerranixConfig =
    config:
    let
      # Check for required terranix structure
      hasValidStructure =
        builtins.isAttrs config
        && (
          config ? terraform || config ? provider || config ? resource || config ? variable || config ? output
        );

      # Validate terraform block if present
      validTerraform =
        if config ? terraform then
          builtins.isAttrs config.terraform
          && (config.terraform ? required_providers -> builtins.isAttrs config.terraform.required_providers)
        else
          true;

      # Validate providers block if present
      validProviders = if config ? provider then builtins.isAttrs config.provider else true;

      # Validate resources block if present
      validResources = if config ? resource then builtins.isAttrs config.resource else true;

      # Validate variables block if present
      validVariables = if config ? variable then builtins.isAttrs config.variable else true;

      # Validate outputs block if present
      validOutputs = if config ? output then builtins.isAttrs config.output else true;

      # Collect validation errors
      errors = lib.filter (x: x != null) [
        (
          if !hasValidStructure then
            "Invalid terranix structure: missing terraform, provider, resource, variable, or output blocks"
          else
            null
        )
        (if !validTerraform then "Invalid terraform block structure" else null)
        (if !validProviders then "Invalid provider block structure" else null)
        (if !validResources then "Invalid resource block structure" else null)
        (if !validVariables then "Invalid variable block structure" else null)
        (if !validOutputs then "Invalid output block structure" else null)
      ];

    in
    if errors == [ ] then
      config
    else
      throw ''
        Terranix configuration validation failed:

        ${lib.concatStringsSep "\n" errors}

        Troubleshooting:
        - Ensure your terranix module returns an attribute set
        - Required blocks: terraform (for providers), resource (for infrastructure),
          provider (for authentication), variable (for inputs), or output (for results)
        - Example: { terraform.required_providers.null = {...}; resource.null_resource.test = {...}; }
        - Check syntax: nix-instantiate --eval your-config.nix
      '';

  # Error reporting utilities
  formatTerranixError =
    error:
    let
      errorStr = toString error;
      lines = lib.splitString "\n" errorStr;

      # Try to extract useful information
      isValidationError = lib.hasPrefix "Terranix validation failed:" errorStr;
      isEvalError = lib.hasPrefix "error:" errorStr;

    in
    if isValidationError then
      "Terranix Configuration Validation Error:\n${lib.concatStringsSep "\n" (lib.drop 1 lines)}"
    else if isEvalError then
      "Terranix Module Evaluation Error:\n${errorStr}"
    else
      "Terranix Error:\n${errorStr}";
}
