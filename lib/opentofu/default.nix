# Enhanced OpenTofu Library - Pure functions for clan services with terranix support
{ lib, pkgs }:

let
  # Import terranix utilities
  terranix = import ./terranix.nix { inherit lib pkgs; };

  # Import backend modules
  backends = import ./backends { inherit lib pkgs; };

  # Import systemd modules
  systemd = import ./systemd { inherit lib pkgs; };
in
rec {
  # Re-export terranix utilities for convenience
  inherit (terranix)
    evalTerranixModule
    generateTerranixJson
    validateTerranixConfig
    testTerranixModule
    introspectTerranixModule
    mkTerranixModule
    jsonToTerranixModule
    formatTerranixError
    terranixModuleType
    terranixConfigType
    ;

  # Re-export backend utilities for convenience
  inherit (backends)
    mkBackend
    autoDetectBackend
    validateBackend
    getBackendServices
    getBackendEnvironment
    getBackendPreSetup
    listSupportedBackends
    isBackendSupported
    # Individual backend modules
    localBackend
    s3Backend
    # Specific backend functions
    generateLocalBackendConfig
    mkLocalBackend
    generateS3BackendConfig
    mkS3Backend
    mkGarageInitService
    ;

  # Re-export systemd utilities for convenience
  inherit (systemd)
    # Health check functions
    healthCheckStrategies
    generateHealthChecks
    registerHealthCheckStrategy
    getAvailableStrategies
    validateHealthCheckStrategy
    # Deployment functions
    mkServiceConfig
    mkDeploymentScript
    mkLockingScript
    # Script generation functions
    mkHelperScripts
    mkHelperScript
    getScriptNames
    validateScriptType
    # Garage-related functions (note: mkGarageInitService is in backends for backward compatibility)
    mkS3CredentialsScript
    validateGarageConfig
    getGarageDependencies
    isGarageBackend
    # Activation functions
    mkPreActivationChecks
    mkPostActivationCleanup
    mkComprehensiveActivationScript
    validateActivationConfig
    # Comprehensive service creation
    mkCompleteSystemdService
    mkQuickDeploymentService
    mkHealthCheckScript
    validateCompleteServiceConfig
    getAvailableFunctions
    # Pure utility functions
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

  # Generate LoadCredential entries for systemd services
  generateLoadCredentials =
    generatorName: credentialMapping:
    lib.mapAttrsToList (
      tfVar: clanVar: "${tfVar}:/run/secrets/vars/${generatorName}/${clanVar}"
    ) credentialMapping;

  # Generate terraform.tfvars script content
  generateTfvarsScript = credentialMapping: extraContent: ''
    # Generate terraform.tfvars from clan vars
    echo "Generating terraform.tfvars with credentials from $CREDENTIALS_DIRECTORY"
    cat > terraform.tfvars <<EOF
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        tfVar: _clanVarsFile:
        "${tfVar} = \"$(cat \"$CREDENTIALS_DIRECTORY/${tfVar}\" | tr -d '\\n\\r' | sed 's/\"/\\\\\"/g')\""
      ) credentialMapping
    )}
    ${extraContent}
    EOF
    echo "Generated terraform.tfvars:"
    cat terraform.tfvars
  '';

  # Re-export mkActivationScript from systemd module (preserving backward compatibility)
  inherit (systemd) mkActivationScript;

  # Re-export mkDeploymentService from systemd module (preserving backward compatibility)
  # NOTE: The modular version now uses extensible health checks instead of hardcoded Keycloak logic
  inherit (systemd) mkDeploymentService;

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
      # Generate terraform configuration from terranix module
      terraformConfigJson = terranix.generateTerranixJson {
        module = terranixModule;
        inherit moduleArgs prettyPrintJson;
        fileName = "${serviceName}-terraform-${instanceName}.json";
        validate = validateConfig;
        debug = debugMode;
      };

    in
    mkDeploymentService {
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

  # Convenience function for terranix-based deployment (preferred for new services)
  # TODO: Re-enable after fixing the recursive dependency issue
  # mkTerranixService = ...; # Commented out for now to test backward compatibility

  # Helper to validate terranix module before deployment
  # TODO: Re-enable after fixing dependency issues
  # validateTerranixService = ...;

  # Migration helper for converting legacy JSON configs to terranix
  # TODO: Re-enable after fixing dependency issues
  # migrateJsonToTerranix = ...;
}
