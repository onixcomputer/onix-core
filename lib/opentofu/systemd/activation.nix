# SystemD Activation Scripts
# Configuration change detection and pre-deployment setup
{ lib, pkgs }:

let
  pure = import ../lib-pure.nix { inherit lib; };
in

rec {
  # Generate activation script for config change detection
  mkTerranixActivation =
    {
      serviceName,
      instanceName,
      # Legacy support
      terraformConfigPath ? null,
      # New terranix support
      terranixModule ? null,
      terranixModuleArgs ? { },
    }:
    let
      # Import terranix utilities if needed for module support
      terranix = import ../terranix.nix { inherit lib pkgs; };

      # Determine the config path to use (same logic as mkTerranixInfrastructure)
      configPath =
        if terranixModule != null then
          terranix.generateTerranixJson {
            module = terranixModule;
            moduleArgs = terranixModuleArgs;
            fileName = "${serviceName}-terranix-${instanceName}.json";
          }
        else if terraformConfigPath != null then
          terraformConfigPath
        else
          throw "mkTerranixActivation: Either terraformConfigPath or terranixModule must be provided";

      stateDir = pure.makeStateDirectory serviceName instanceName;

    in
    {
      text = ''
        echo "Checking for ${serviceName} terraform configuration changes..."

        # Create state directory if it doesn't exist
        mkdir -p ${stateDir}

        # Check if terraform configuration has changed
        CURRENT_CONFIG_HASH=$(sha256sum ${configPath} | cut -d' ' -f1)
        LAST_DEPLOY_HASH=$(cat ${stateDir}/.last-deploy-hash 2>/dev/null || echo "")

        if [ "$CURRENT_CONFIG_HASH" != "$LAST_DEPLOY_HASH" ]; then
          echo "✓ Terraform configuration changed - clearing deploy flag"
          rm -f ${stateDir}/.deploy-complete
          echo "  Previous hash: $LAST_DEPLOY_HASH"
          echo "  Current hash:  $CURRENT_CONFIG_HASH"
        else
          echo "✓ Terraform configuration unchanged"
        fi

        # Ensure proper permissions on state directory
        chmod 755 ${stateDir}
      '';
      deps = [ "setupSecrets" ];
    };

  # Generate pre-activation checks
  mkPreActivationChecks =
    {
      serviceName,
      instanceName,
      requiredServices ? [ ],
      requiredDirectories ? [ ],
      requiredFiles ? [ ],
    }:
    let
      stateDir = pure.makeStateDirectory serviceName instanceName;
    in
    {
      text = ''
        echo "Running pre-activation checks for ${serviceName}-${instanceName}..."

        # Check required services
        ${lib.concatStringsSep "\n" (
          map (service: ''
            if ! systemctl is-enabled ${service} >/dev/null 2>&1; then
              echo "WARNING: Required service ${service} is not enabled"
            fi
          '') requiredServices
        )}

        # Check required directories
        ${lib.concatStringsSep "\n" (
          map (dir: ''
            if [ ! -d "${dir}" ]; then
              echo "Creating required directory: ${dir}"
              mkdir -p "${dir}"
            fi
          '') (requiredDirectories ++ [ stateDir ])
        )}

        # Check required files
        ${lib.concatStringsSep "\n" (
          map (file: ''
            if [ ! -f "${file}" ]; then
              echo "WARNING: Required file ${file} does not exist"
            fi
          '') requiredFiles
        )}

        echo "✓ Pre-activation checks completed for ${serviceName}-${instanceName}"
      '';
      deps = [ "setupSecrets" ];
    };

  # Generate post-activation cleanup
  mkPostActivationCleanup =
    {
      serviceName,
      instanceName,
      cleanupOldConfigs ? true,
      cleanupTempFiles ? true,
      maxConfigHistory ? 5,
    }:
    let
      stateDir = pure.makeStateDirectory serviceName instanceName;
    in
    {
      text = ''
        echo "Running post-activation cleanup for ${serviceName}-${instanceName}..."

        ${lib.optionalString cleanupTempFiles ''
          # Clean up temporary files
          find ${stateDir} -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
          find ${stateDir} -name "*.log" -mtime +7 -delete 2>/dev/null || true
        ''}

        ${lib.optionalString cleanupOldConfigs ''
          # Keep only the last ${toString maxConfigHistory} config hashes
          if [ -f "${stateDir}/.config-history" ]; then
            tail -n ${toString maxConfigHistory} "${stateDir}/.config-history" > "${stateDir}/.config-history.tmp"
            mv "${stateDir}/.config-history.tmp" "${stateDir}/.config-history"
          fi
        ''}

        echo "✓ Post-activation cleanup completed for ${serviceName}-${instanceName}"
      '';
      deps = [ ];
    };

  # Comprehensive activation script with pre/post hooks
  mkComprehensiveActivationScript =
    {
      serviceName,
      instanceName,
      terraformConfigPath ? null,
      terranixModule ? null,
      terranixModuleArgs ? { },
      requiredServices ? [ ],
      requiredDirectories ? [ ],
      requiredFiles ? [ ],
      cleanupOldConfigs ? true,
      cleanupTempFiles ? true,
      maxConfigHistory ? 5,
    }:
    let
      preChecks = mkPreActivationChecks {
        inherit
          serviceName
          instanceName
          requiredServices
          requiredDirectories
          requiredFiles
          ;
      };

      mainScript = mkTerranixActivation {
        inherit
          serviceName
          instanceName
          terraformConfigPath
          terranixModule
          terranixModuleArgs
          ;
      };

      postCleanup = mkPostActivationCleanup {
        inherit
          serviceName
          instanceName
          cleanupOldConfigs
          cleanupTempFiles
          maxConfigHistory
          ;
      };

    in
    {
      text = preChecks.text + "\n\n" + mainScript.text + "\n\n" + postCleanup.text;
      inherit (mainScript) deps;
    };

  # Validate activation script configuration
  validateActivationConfig =
    {
      terraformConfigPath ? null,
      terranixModule ? null,
      ...
    }:
    let
      hasConfigPath = terraformConfigPath != null;
      hasTerranixModule = terranixModule != null;
    in
    if !(hasConfigPath || hasTerranixModule) then
      throw "validateActivationConfig: Either terraformConfigPath or terranixModule must be provided"
    else if hasConfigPath && hasTerranixModule then
      throw "validateActivationConfig: Only one of terraformConfigPath or terranixModule should be provided"
    else
      true;
}
