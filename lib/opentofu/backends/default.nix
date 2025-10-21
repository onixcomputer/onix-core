# Unified Backend Configuration Interface
# Provides a single entry point for all backend types with automatic dispatching
{ lib, pkgs }:

let
  # Import backend modules
  localBackend = import ./local.nix { inherit lib pkgs; };
  s3Backend = import ./s3.nix { inherit lib pkgs; };

  # Backend type mappings
  backendModules = {
    local = localBackend;
    s3 = s3Backend;
  };

  # Supported backend types
  supportedBackendTypes = builtins.attrNames backendModules;
in
{
  # Re-export individual backend modules
  inherit localBackend s3Backend;

  # Re-export specific backend functions for convenience
  inherit (localBackend) generateLocalBackendConfig mkLocalBackend;
  inherit (s3Backend) generateS3BackendConfig mkS3Backend mkTerranixGarageBackend;

  # Main unified backend creation function
  mkBackend =
    {
      serviceName,
      instanceName,
      backendType ? "local",
      # S3-specific options
      endpoint ? "http://127.0.0.1:3900",
      bucket ? "terraform-state",
      region ? "garage",
    }:
    let
      # Validate backend type
      validateBackendType =
        type:
        if builtins.elem type supportedBackendTypes then
          type
        else
          throw ''
            mkBackend: Unsupported backend type '${type}'

            Supported backend types: ${lib.concatStringsSep ", " supportedBackendTypes}

            Backend type guide:
            • "local": Store terraform state on local filesystem
              - Good for: Development, single-machine deployments
              - Limitations: No shared state, no concurrent access
              - Example: backendType = "local";

            • "s3": Store terraform state in S3-compatible storage (Garage)
              - Good for: Production, shared state, team collaboration
              - Requires: Garage service running on the machine
              - Example: backendType = "s3";

            Common fixes:
            ❌ backendType = "remote";     # Not supported
            ✅ backendType = "s3";         # Use S3/Garage for remote state

            ❌ backendType = "gcs";        # Not supported yet
            ✅ backendType = "s3";         # Use S3/Garage alternative

            ❌ backendType = "consul";     # Not supported yet
            ✅ backendType = "local";      # Use local for now

            Need shared state? Set up Garage service and use backendType = "s3"
            Just experimenting? Use backendType = "local" for simple setups
          '';

      validatedType = validateBackendType backendType;

      # Common parameters for all backends
      commonParams = { inherit serviceName instanceName; };

      # Backend-specific configurations
      backendConfigs = {
        local = localBackend.mkLocalBackend commonParams;
        s3 =
          if endpoint != "http://127.0.0.1:3900" || bucket != "terraform-state" || region != "garage" then
            # Use custom S3 backend if non-default parameters provided
            s3Backend.mkCustomS3Backend {
              inherit
                serviceName
                instanceName
                endpoint
                bucket
                region
                ;
            }
          else
            # Use standard S3 backend
            s3Backend.mkS3Backend commonParams;
      };
    in
    backendConfigs.${validatedType};

  # Auto-detect appropriate backend type based on configuration
  autoDetectBackend =
    {
      serviceName,
      instanceName,
      requiresSharedState ? false,
      hasGarageService ? false,
      # S3-specific options
      endpoint ? "http://127.0.0.1:3900",
      bucket ? "terraform-state",
      region ? "garage",
    }:
    let
      # Logic for backend selection
      selectedType = if requiresSharedState && hasGarageService then "s3" else "local";

      # Common parameters for all backends
      commonParams = { inherit serviceName instanceName; };

      # Backend-specific configurations
      backendConfigs = {
        local = localBackend.mkLocalBackend commonParams;
        s3 =
          if endpoint != "http://127.0.0.1:3900" || bucket != "terraform-state" || region != "garage" then
            # Use custom S3 backend if non-default parameters provided
            s3Backend.mkCustomS3Backend {
              inherit
                serviceName
                instanceName
                endpoint
                bucket
                region
                ;
            }
          else
            # Use standard S3 backend
            s3Backend.mkS3Backend commonParams;
      };
    in
    backendConfigs.${selectedType};

  # Validate backend configuration for any type
  validateBackend =
    backendConfig:
    let
      requiredFields = [
        "backendType"
        "backendConfig"
        "backendScript"
        "stateDirectory"
      ];
      missingFields = builtins.filter (field: !(backendConfig ? ${field})) requiredFields;
    in
    if missingFields != [ ] then
      throw ''
        validateBackend: Invalid backend configuration

        Missing required fields: ${lib.concatStringsSep ", " missingFields}

        Backend configuration must include:
        • backendType: "local" or "s3"
        • backendConfig: Configuration file content
        • backendScript: Script to set up the backend
        • stateDirectory: Directory for terraform state

        This is an internal error - you shouldn't be calling validateBackend directly.

        Instead, use:
        opentofu.mkBackend {
          backendType = "s3";  # or "local"
          serviceName = "your-service";
          instanceName = "your-instance";
        }

        Or use higher-level functions:
        opentofu.mkTerranixService { backendType = "s3"; /* ... */ }
      ''
    else if !(builtins.elem backendConfig.backendType supportedBackendTypes) then
      throw ''
        validateBackend: Invalid backend configuration

        Unsupported backend type: '${backendConfig.backendType}'
        Supported types: ${lib.concatStringsSep ", " supportedBackendTypes}

        This is an internal validation error. The backend type should have been
        validated earlier by mkBackend.

        If you're seeing this error, it suggests an internal library bug.
        Please check that you're using supported backend types:
        • "local": Local filesystem storage
        • "s3": S3/Garage distributed storage
      ''
    else
      backendConfig;

  # Helper to get backend-specific services
  getBackendServices =
    {
      backendType,
      serviceName,
      instanceName,
    }:
    if backendType == "s3" then
      s3Backend.mkTerranixGarageBackend { inherit serviceName instanceName; }
    else
      { };

  # Helper to get backend-specific environment setup
  getBackendEnvironment = backendConfig: backendConfig.environmentVariables or { };

  # Helper to get backend-specific pre-setup script
  getBackendPreSetup = backendConfig: backendConfig.preSetupScript or "";

  # Utility functions for backend management
  listSupportedBackends = supportedBackendTypes;

  # Check if backend type is available
  isBackendSupported = backendType: builtins.elem backendType supportedBackendTypes;

  # Get backend module for a specific type
  getBackendModule =
    backendType:
    if builtins.elem backendType supportedBackendTypes then
      backendModules.${backendType}
    else
      throw "getBackendModule: Unsupported backend type '${backendType}'";

  # Create backend configuration for migration scenarios
  mkMigrationBackend =
    {
      fromBackendType,
      toBackendType,
      serviceName,
      instanceName,
    }:
    let
      # Common parameters for all backends
      commonParams = { inherit serviceName instanceName; };

      # Backend configurations using direct calls to avoid circular dependencies
      backendConfigs = {
        local = localBackend.mkLocalBackend commonParams;
        s3 = s3Backend.mkS3Backend commonParams;
      };

      fromBackend = backendConfigs.${fromBackendType};
      toBackend = backendConfigs.${toBackendType};
    in
    {
      from = fromBackend;
      to = toBackend;
      migrationScript = ''
        echo "Migrating terraform state from ${fromBackendType} to ${toBackendType}"
        # Migration logic would be implemented here
        # This is a placeholder for future migration functionality
      '';
    };

  # Debug function to introspect backend configuration
  debugBackend = backendConfig: {
    inherit (backendConfig) backendType;
    hasAdditionalServices = backendConfig.additionalServices != { };
    inherit (backendConfig) stateDirectory;
    environmentVariables = builtins.attrNames (backendConfig.environmentVariables or { });
    hasPreSetupScript = (backendConfig.preSetupScript or "") != "";
  };
}
