# Terranix Module Library - Enhanced terranix integration for clan services
{ lib, pkgs }:

let
  inherit (lib) mkOption types;
in
rec {
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
      throw "Terranix validation failed:\n${lib.concatStringsSep "\n" errors}";

  # Evaluate terranix module and return JSON configuration
  evalTerranixModule =
    {
      # Terranix module to evaluate
      module,
      # Settings/arguments to pass to the module
      moduleArgs ? { },
      # Debug mode - includes source information
      debug ? false,
      # Validation mode - strict type checking
      validate ? true,
    }:
    let
      # Use only the provided moduleArgs (don't add extra lib/pkgs that might conflict)
      evalArgs = moduleArgs;

      # Evaluate the terranix module
      evaluated =
        if builtins.isFunction module then
          module evalArgs
        else if builtins.isPath module then
          import module evalArgs
        else if builtins.isString module then
          import (/. + module) evalArgs
        else
          module;

      # Validate the result if requested
      validatedResult = if validate then validateTerranixConfig evaluated else evaluated;

      # Add debug information if requested
      resultWithDebug =
        if debug then
          validatedResult
          // {
            _debug = {
              moduleSource = toString module;
              evaluationArgs = builtins.attrNames evalArgs;
            };
          }
        else
          validatedResult;

    in
    resultWithDebug;

  # Generate JSON configuration from terranix module
  generateTerranixJson =
    {
      # Terranix module to evaluate
      module,
      # Settings/arguments to pass to the module
      moduleArgs ? { },
      # Output file name
      fileName ? "terraform.json",
      # Pretty print JSON
      prettyPrintJson ? false,
      # Validation options
      validate ? true,
      # Debug mode
      debug ? false,
    }:
    let
      evaluated = evalTerranixModule {
        inherit
          module
          moduleArgs
          validate
          debug
          ;
      };

    in
    if prettyPrintJson then
      pkgs.runCommand fileName { nativeBuildInputs = [ pkgs.jq ]; } ''
        echo '${builtins.toJSON evaluated}' | jq . > $out
      ''
    else
      pkgs.writeText fileName (builtins.toJSON evaluated);

  # Enhanced deployment service that works with terranix modules
  mkTerranixDeploymentService =
    {
      # Service configuration
      serviceName,
      instanceName,

      # Terranix module configuration
      terranixModule,
      moduleArgs ? { },

      # Credential mapping for OpenTofu library compatibility
      credentialMapping ? { },

      # Deployment options
      dependencies ? [ ],
      backendType ? "local",
      timeoutSec ? "10m",
      preTerraformScript ? "",
      postTerraformScript ? "",

      # Terranix-specific options
      validateConfig ? true,
      debugMode ? false,
      prettyPrintJson ? false,
    }:
    let
      # Import the base OpenTofu library
      opentofu = import ./default.nix { inherit lib pkgs; };

      # Generate terraform configuration from terranix module
      terraformConfigJson = generateTerranixJson {
        module = terranixModule;
        inherit moduleArgs prettyPrintJson;
        fileName = "${serviceName}-terraform-${instanceName}.json";
        validate = validateConfig;
        debug = debugMode;
      };

    in
    opentofu.mkDeploymentService {
      inherit
        serviceName
        instanceName
        credentialMapping
        dependencies
        backendType
        timeoutSec
        ;
      terraformConfigPath = terraformConfigJson;
      preTerraformScript = preTerraformScript + ''
        echo "Using terranix-generated configuration: ${terraformConfigJson}"
        ${lib.optionalString debugMode ''
          echo "Terranix debug mode enabled"
          echo "Configuration preview:"
          head -20 ${terraformConfigJson} || true
        ''}
      '';
      inherit postTerraformScript;
    };

  # Testing utilities for terranix configurations
  testTerranixModule =
    {
      # Module to test
      module,
      # Test cases - attribute set of test scenarios
      testCases ? { },
      # Expected validation to pass
      shouldValidate ? true,
      # Expected structure checks
      expectedBlocks ? [ ],
    }:
    let
      # Run each test case
      testResults = lib.mapAttrs (
        testName: testArgs:
        let
          # Try to evaluate the module, catching errors
          testResult = builtins.tryEval (evalTerranixModule {
            inherit module;
            moduleArgs = testArgs;
            validate = shouldValidate;
          });

          # Check expected blocks if test succeeded
          blockChecks =
            if testResult.success && expectedBlocks != [ ] then
              lib.all (block: testResult.value ? ${block}) expectedBlocks
            else
              true;

        in
        {
          inherit (testResult) success;
          result = if testResult.success then testResult.value else null;
          error = if testResult.success then null else "Evaluation failed";
          inherit blockChecks;
          inherit testName;
        }
      ) testCases;

      # Collect test summary
      summary = {
        total = builtins.length (builtins.attrNames testResults);
        passed = builtins.length (
          lib.filter (test: test.success && test.blocksValid) (builtins.attrValues testResults)
        );
        failed = builtins.length (
          lib.filter (test: !test.success || !test.blocksValid) (builtins.attrValues testResults)
        );
      };

    in
    {
      inherit testResults summary;
      allPassed = summary.failed == 0;
    };

  # Debug and introspection utilities
  introspectTerranixModule =
    {
      # Module to introspect
      module,
      # Arguments for introspection
      moduleArgs ? { },
    }:
    let
      # Evaluate with debug mode
      evaluated = evalTerranixModule {
        inherit module moduleArgs;
        debug = true;
        validate = false; # Don't validate during introspection
      };

      # Extract structure information
      structure = {
        hasProviders = evaluated ? provider;
        hasResources = evaluated ? resource;
        hasVariables = evaluated ? variable;
        hasOutputs = evaluated ? output;
        hasTerraform = evaluated ? terraform;

        # Count elements
        providerCount =
          if evaluated ? provider then builtins.length (builtins.attrNames evaluated.provider) else 0;
        resourceCount =
          if evaluated ? resource then
            builtins.length (
              lib.flatten (lib.mapAttrsToList (_: resources: builtins.attrNames resources) evaluated.resource)
            )
          else
            0;
        variableCount =
          if evaluated ? variable then builtins.length (builtins.attrNames evaluated.variable) else 0;
        outputCount =
          if evaluated ? output then builtins.length (builtins.attrNames evaluated.output) else 0;
      };

      # Extract provider information
      providers = lib.optionalAttrs (evaluated ? provider) {
        names = builtins.attrNames evaluated.provider;
        details = evaluated.provider;
      };

      # Extract resource types
      resourceTypes = lib.optionalAttrs (evaluated ? resource) (builtins.attrNames evaluated.resource);

      # Extract variables
      variables = lib.optionalAttrs (evaluated ? variable) (
        lib.mapAttrs (_: var: {
          type = var.type or "unknown";
          description = var.description or null;
          hasDefault = var ? default;
          sensitive = var.sensitive or false;
        }) evaluated.variable
      );

      # Extract outputs
      outputs = lib.optionalAttrs (evaluated ? output) (
        lib.mapAttrs (_: output: {
          description = output.description or null;
          sensitive = output.sensitive or false;
        }) evaluated.output
      );

    in
    {
      inherit
        structure
        providers
        resourceTypes
        variables
        outputs
        ;
      debugInfo = evaluated._debug or { };
      rawConfig = evaluated;
    };

  # Utility to create terranix module from simple configuration
  mkTerranixModule =
    {
      # Terraform configuration blocks
      terraform ? { },
      providers ? { },
      variables ? { },
      resources ? { },
      outputs ? { },

      # Additional configuration
      extraConfig ? { },
    }:
    _:
    {
      inherit terraform;
      provider = providers;
      variable = variables;
      resource = resources;
      output = outputs;
    }
    // extraConfig;

  # Helper to convert legacy JSON configs to terranix modules
  jsonToTerranixModule =
    jsonFile: _:
    let
      jsonContent = builtins.fromJSON (builtins.readFile jsonFile);
    in
    jsonContent;

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

  # Type definitions for terranix configurations
  terranixModuleType = types.either types.path (types.functionTo types.attrs);

  terranixConfigType = types.submodule {
    options = {
      terraform = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Terraform configuration block";
      };

      provider = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Provider configurations";
      };

      variable = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Variable definitions";
      };

      resource = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Resource definitions";
      };

      output = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Output definitions";
      };
    };
  };
}
