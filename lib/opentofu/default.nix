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
    ;

  # Re-export systemd utilities for convenience
  inherit (systemd)
    # Health check functions
    healthCheckStrategies
    generateHealthChecks
    registerHealthCheckStrategy
    getAvailableStrategies
    validateHealthCheckStrategy
    # Deployment functions (new terranix-focused names)
    mkServiceConfig
    mkDeploymentScript
    mkLockingScript
    mkTerranixInfrastructure
    # Script generation functions
    mkTerranixScripts
    mkHelperScript
    getScriptNames
    validateScriptType
    # Garage-related functions
    mkTerranixGarageBackend
    mkS3CredentialsScript
    validateGarageConfig
    getGarageDependencies
    isGarageBackend
    # Activation functions (new terranix-focused names)
    mkTerranixActivation
    mkTerranixComprehensiveActivation
    mkPreActivationChecks
    mkPostActivationCleanup
    mkComprehensiveActivationScript
    validateActivationConfig
    # Comprehensive service creation (new terranix-focused names)
    mkTerranixService
    mkTerranixDeployment
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

  # Re-export validation functions for user access
  inherit ((import ./pure/credentials.nix { inherit lib; })) validateCredentialMapping;
  inherit ((import ./terranix/validation.nix { inherit lib; })) detectCommonFailures;

  # Note: Primary terranix-focused API:
  # - mkTerranixService: Complete service creation with full terranix integration
  # - mkTerranixInfrastructure: Core deployment function for terranix modules
  # - mkTerranixDeployment: Quick deployment wrapper
  # - mkTerranixActivation: Activation script with terranix support
  # - mkTerranixScripts: Helper scripts for terranix workflows
  # - mkTerranixGarageBackend: S3/Garage backend for terranix state
}
