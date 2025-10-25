# SystemD Helper Scripts Generation
# Utility scripts for terraform operations management
{ lib, pkgs }:

let
  pure = import ../lib-pure.nix { inherit lib; };
in

rec {
  # Generate helper scripts for terraform operations
  mkTerranixScripts =
    {
      serviceName,
      instanceName,
    }:
    let
      stateDir = pure.makeStateDirectory serviceName instanceName;
      lockFile = pure.makeLockFile serviceName instanceName;
      lockInfoFile = pure.makeLockInfoFile serviceName instanceName;
      deploymentServiceName = pure.makeDeploymentServiceName serviceName instanceName;

      # Script name generators
      unlockScriptName = pure.makeUnlockScriptName serviceName instanceName;
      statusScriptName = pure.makeStatusScriptName serviceName instanceName;
      applyScriptName = pure.makeApplyScriptName serviceName instanceName;
      logsScriptName = pure.makeLogsScriptName serviceName instanceName;

    in
    [
      # Unlock script - Force remove terraform state locks
      (pkgs.writeScriptBin unlockScriptName ''
        #!${pkgs.bash}/bin/bash
        LOCK_FILE="${lockFile}"
        LOCK_INFO="${lockInfoFile}"

        if [ ! -f "$LOCK_FILE" ] && [ ! -f "$LOCK_INFO" ]; then
          echo "No lock files found"
          exit 0
        fi

        echo "Current lock status:"
        if [ -f "$LOCK_INFO" ]; then
          cat "$LOCK_INFO"
        fi

        read -p "Force unlock terraform state? (y/N) " -n 1 -r
        echo
        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
          rm -f "$LOCK_FILE" "$LOCK_INFO"
          echo "Lock removed"
        else
          echo "Cancelled"
        fi
      '')

      # Status script - Show lock status and service health
      (pkgs.writeScriptBin statusScriptName ''
        #!${pkgs.bash}/bin/bash
        LOCK_FILE="${lockFile}"
        LOCK_INFO="${lockInfoFile}"

        echo "=== Terraform Lock Status for ${serviceName}-${instanceName} ==="
        if [ -f "$LOCK_FILE" ] || [ -f "$LOCK_INFO" ]; then
          echo "Lock is ACTIVE"
          if [ -f "$LOCK_INFO" ]; then
            echo "Lock details:"
            cat "$LOCK_INFO"
          fi

          # Check if the PID is still running
          if [ -f "$LOCK_INFO" ]; then
            PID=$(grep "^PID:" "$LOCK_INFO" | awk '{print $2}')
            if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
              echo "Process $PID is still running"
            else
              echo "WARNING: Process $PID is not running (lock may be stale)"
            fi
          fi
        else
          echo "No active lock"
        fi

        echo ""
        echo "=== Terraform Deployment Service Status ==="
        systemctl status --no-pager -l ${deploymentServiceName}.service || true

        echo ""
        echo "=== Main Service Status ==="
        systemctl status --no-pager -l ${serviceName}.service || true
      '')

      # Apply script - Manual terraform deployment trigger
      (pkgs.writeScriptBin applyScriptName ''
        #!${pkgs.bash}/bin/bash
        echo "Triggering terraform apply for ${serviceName}-${instanceName}..."

        # Remove deploy-complete flag to force re-deployment
        rm -f ${stateDir}/.deploy-complete

        # Start the deployment service
        systemctl start ${deploymentServiceName}.service

        # Follow the logs
        journalctl -u ${deploymentServiceName}.service -f
      '')

      # Logs script - Monitor terraform execution
      (pkgs.writeScriptBin logsScriptName ''
        #!${pkgs.bash}/bin/bash
        echo "Monitoring terraform logs for ${serviceName}-${instanceName}..."

        echo "=== Current Status ==="
        echo "Main service: $(systemctl is-active ${serviceName}.service)"
        echo "Deployment service: $(systemctl is-active ${deploymentServiceName}.service)"

        # Check for deploy-complete flag
        if [ -f "${stateDir}/.deploy-complete" ]; then
          echo "Deploy status: COMPLETE"
        else
          echo "Deploy status: PENDING"
        fi

        # Check for lock status
        if [ -f "${lockFile}" ] || [ -f "${lockInfoFile}" ]; then
          echo "Lock status: ACTIVE"
        else
          echo "Lock status: NONE"
        fi

        echo ""
        echo "=== Following Deployment Service Logs ==="
        echo "Press Ctrl+C to stop following logs"
        journalctl -u ${deploymentServiceName}.service -f
      '')
    ];

  # Generate a single helper script by name
  mkHelperScript =
    {
      serviceName,
      instanceName,
      scriptType, # "unlock" | "status" | "apply" | "logs"
    }:
    let
      allScripts = mkTerranixScripts { inherit serviceName instanceName; };
      scriptMap = {
        unlock = builtins.elemAt allScripts 0;
        status = builtins.elemAt allScripts 1;
        apply = builtins.elemAt allScripts 2;
        logs = builtins.elemAt allScripts 3;
      };
    in
    if builtins.hasAttr scriptType scriptMap then
      scriptMap.${scriptType}
    else
      throw "mkHelperScript: Unknown script type '${scriptType}'. Valid types: unlock, status, apply, logs";

  # Get script names for a service instance
  getScriptNames = serviceName: instanceName: {
    unlock = pure.makeUnlockScriptName serviceName instanceName;
    status = pure.makeStatusScriptName serviceName instanceName;
    apply = pure.makeApplyScriptName serviceName instanceName;
    logs = pure.makeLogsScriptName serviceName instanceName;
  };

  # Validate script type
  validateScriptType =
    scriptType:
    let
      validTypes = [
        "unlock"
        "status"
        "apply"
        "logs"
      ];
    in
    if builtins.elem scriptType validTypes then
      scriptType
    else
      throw "validateScriptType: Invalid script type '${scriptType}'. Valid types: ${lib.concatStringsSep ", " validTypes}";
}
