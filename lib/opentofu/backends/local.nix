# Local Backend Configuration Module
# Provides functions for local filesystem-based terraform state management
{ lib }:

let
  # Import pure functions from lib-pure.nix
  pureFuncs = import ../lib-pure.nix { inherit lib; };
in
{
  # Generate local backend configuration content
  inherit (pureFuncs) generateLocalBackendConfig;

  # Create a complete local backend configuration for a service
  mkLocalBackend =
    { serviceName, instanceName }:
    {
      # Backend configuration file content
      backendConfig = pureFuncs.generateLocalBackendConfig;

      # Script to write backend configuration
      backendScript = ''
        # Local backend
        cat > backend.tf <<'EOF'
        ${pureFuncs.generateLocalBackendConfig}
        EOF
      '';

      # Backend type identifier
      backendType = "local";

      # No additional services needed for local backend
      additionalServices = { };

      # State directory path
      stateDirectory = pureFuncs.makeStateDirectory serviceName instanceName;

      # Backend-specific environment variables (none for local)
      environmentVariables = { };

      # Pre-terraform setup script (none needed for local)
      preSetupScript = "";
    };

  # Validate local backend configuration
  validateLocalBackend = config: config; # Local backend has no special validation requirements

  # Helper to check if local backend is suitable for given configuration
  isLocalBackendSuitable = _: true; # Always suitable as fallback
}
