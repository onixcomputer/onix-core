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
    # Garage-related functions (note: mkGarageInitService is in backends for backward compatibility)
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
    # Backward compatibility aliases
    mkDeploymentService
    mkCompleteSystemdService
    mkQuickDeploymentService
    mkActivationScript
    mkHelperScripts
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

  # Note: Terranix-focused functions are the primary interface.
  # Backward compatibility functions are available through the systemd module exports above.

  # Note: High-level terranix-focused functions are the primary interface:
  # - mkTerranixService: Full-featured service creation with comprehensive terranix support
  # - mkTerranixDeployment: Simplified deployment service creation
  # - mkTerranixInfrastructure: Core infrastructure deployment function
  # - mkTerranixActivation: Enhanced activation script generation
  # - mkTerranixScripts: Helper scripts with terranix awareness
  #
  # Backward compatibility functions maintain the old naming for existing code.
  # These provide complete service creation including systemd services, activation
  # scripts, helper scripts, and backend initialization.
}
