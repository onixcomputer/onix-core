# SystemD Service Generation - Modular Entry Point
# Imports and re-exports all systemd-related functions with proper dependency management
{ lib, pkgs }:

let
  # Import all systemd modules
  healthChecks = import ./health-checks.nix { inherit lib; };
  deployment = import ./deployment.nix { inherit lib pkgs; };
  scripts = import ./scripts.nix { inherit lib pkgs; };
  garage = import ./garage.nix { inherit lib pkgs; };
  activation = import ./activation.nix { inherit lib pkgs; };

  # Import pure functions for utility
  pure = import ../lib-pure.nix { inherit lib; };
in

rec {
  # Re-export all health check functions
  inherit (healthChecks)
    healthCheckStrategies
    generateHealthChecks
    registerHealthCheckStrategy
    getAvailableStrategies
    validateHealthCheckStrategy
    ;

  # Re-export all deployment functions
  inherit (deployment)
    mkServiceConfig
    mkDeploymentScript
    mkLockingScript
    mkTerranixInfrastructure
    ;

  # Re-export all script generation functions
  inherit (scripts)
    mkTerranixScripts
    mkHelperScript
    getScriptNames
    validateScriptType
    ;

  # Re-export all garage-related functions
  inherit (garage)
    mkTerranixGarageBackend
    mkS3CredentialsScript
    validateGarageConfig
    getGarageDependencies
    isGarageBackend
    ;

  # Re-export all activation functions
  inherit (activation)
    mkTerranixActivation
    mkPreActivationChecks
    mkPostActivationCleanup
    mkComprehensiveActivationScript
    validateActivationConfig
    ;

  # Terranix-focused activation function aliases (new naming convention)
  mkTerranixComprehensiveActivation = activation.mkComprehensiveActivationScript;

  # Re-export pure utility functions for convenience
  inherit (pure)
    makeServiceName
    makeStateDirectory
    makeLockFile
    makeLockInfoFile
    makeDeploymentServiceName
    makeGarageInitServiceName
    makeUnlockScriptName
    makeStatusScriptName
    makeApplyScriptName
    makeLogsScriptName
    makeDeployCompleteFile
    extractServiceComponents
    ;

  # Comprehensive service creation with all components
  mkTerranixService =
    {
      serviceName,
      instanceName,
      # Configuration source
      terraformConfigPath ? null,
      terranixModule ? null,
      terranixModuleArgs ? { },
      terranixValidate ? true,
      terranixDebug ? false,
      # Service configuration
      credentialMapping,
      dependencies ? [ ],
      backendType ? "local",
      timeoutSec ? "10m",
      preTerraformScript ? "",
      postTerraformScript ? "",
      # Activation script options
      requiredServices ? [ ],
      requiredDirectories ? [ ],
      requiredFiles ? [ ],
      cleanupOldConfigs ? true,
      cleanupTempFiles ? true,
      maxConfigHistory ? 5,
      # Helper scripts
      generateHelperScripts ? true,
    }:
    let
      # Validate inputs

      # Generate core deployment service
      deploymentService = deployment.mkTerranixInfrastructure {
        inherit
          serviceName
          instanceName
          terraformConfigPath
          terranixModule
          terranixModuleArgs
          terranixValidate
          terranixDebug
          credentialMapping
          dependencies
          backendType
          timeoutSec
          preTerraformScript
          postTerraformScript
          ;
      };

      # Generate activation script
      activationScript = activation.mkComprehensiveActivationScript {
        inherit
          serviceName
          instanceName
          terraformConfigPath
          terranixModule
          terranixModuleArgs
          requiredServices
          requiredDirectories
          requiredFiles
          cleanupOldConfigs
          cleanupTempFiles
          maxConfigHistory
          ;
      };

      # Generate Garage init service if using S3 backend
      garageService = lib.optionalAttrs (garage.isGarageBackend backendType) (
        garage.mkTerranixGarageBackend { inherit serviceName instanceName; }
      );

      # Generate helper scripts if requested
      helperScripts =
        if generateHelperScripts then
          scripts.mkTerranixScripts { inherit serviceName instanceName; }
        else
          [ ];

    in
    {
      # SystemD services
      systemd.services = deploymentService // garageService;

      # Activation script
      system.activationScripts."${serviceName}-${instanceName}-terraform" = activationScript;

      # Helper scripts in system packages
      environment.systemPackages = helperScripts;

      # Service metadata for introspection
      _meta = {
        inherit serviceName instanceName backendType;
        hasGarageInit = garage.isGarageBackend backendType;
        hasHelperScripts = generateHelperScripts;
        scriptNames =
          if generateHelperScripts then scripts.getScriptNames serviceName instanceName else { };
        healthCheckStrategy =
          if builtins.hasAttr serviceName healthChecks.healthCheckStrategies then serviceName else "generic";
      };
    };

  # Quick deployment service creation (minimal options)
  mkTerranixDeployment =
    {
      serviceName,
      instanceName,
      credentialMapping,
      terraformConfigPath ? null,
      terranixModule ? null,
      dependencies ? [ ],
    }:
    deployment.mkTerranixInfrastructure {
      inherit
        serviceName
        instanceName
        credentialMapping
        terraformConfigPath
        terranixModule
        dependencies
        ;
    };

  # Health check only (for testing/validation)
  mkHealthCheckScript = serviceName: healthChecks.generateHealthChecks serviceName;

  # Validate complete service configuration
  validateCompleteServiceConfig =
    config:
    let
      requiredFields = [
        "serviceName"
        "instanceName"
        "credentialMapping"
      ];
      missingFields = builtins.filter (
        field: !builtins.hasAttr field config || config.${field} == null
      ) requiredFields;
    in
    if missingFields == [ ] then
      config
    else
      let
        fieldHelp = {
          serviceName = ''
            serviceName: Unique identifier for your service
            Example: serviceName = "postgres"; or serviceName = "redis";
          '';
          instanceName = ''
            instanceName: Environment or instance identifier
            Example: instanceName = "production"; or instanceName = "dev";
          '';
          credentialMapping = ''
            credentialMapping: Maps terraform variables to clan variables
            Example: credentialMapping = { admin_password = "postgres_password"; };
            Use { } if no credentials needed.
          '';
        };

        fieldGuidance = lib.concatStringsSep "\n\n" (
          map (field: fieldHelp.${field} or "• ${field}: Required parameter") missingFields
        );
      in
      throw ''
        validateCompleteServiceConfig: Missing required configuration

        Missing fields: ${lib.concatStringsSep ", " missingFields}

        Field requirements:
        ${fieldGuidance}

        Complete working example:
        opentofu.mkTerranixService {
          serviceName = "postgres";
          instanceName = "production";
          terranixModule = ./postgres-config.nix;
          credentialMapping = {
            admin_password = "postgres_admin_password";
            readonly_password = "postgres_readonly_password";
          };
          backendType = "s3";  # or "local"
          dependencies = [ "postgresql.service" ];
        }

        Need simpler API? Try opentofu.mkTerranixDeployment for fewer required fields.
      '';

  # Get all available systemd functions (for introspection)
  getAvailableFunctions = {
    healthChecks = builtins.attrNames healthChecks;
    deployment = builtins.attrNames deployment;
    scripts = builtins.attrNames scripts;
    garage = builtins.attrNames garage;
    activation = builtins.attrNames activation;
  };
}
