# Simple OpenTofu Library - Pure functions for clan services
{ lib, pkgs }:

{
  # Generate LoadCredential entries for systemd services
  generateLoadCredentials =
    generatorName: credentialMapping:
    lib.mapAttrsToList (
      tfVar: clanVar: "${tfVar}:/run/secrets/vars/${generatorName}/${clanVar}"
    ) credentialMapping;

  # Generate terraform.tfvars script content
  generateTfvarsScript = credentialMapping: extraContent: ''
    # Generate terraform.tfvars from clan vars
    cat > terraform.tfvars <<EOF
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        tfVar: _: "${tfVar} = \"$(cat $CREDENTIALS_DIRECTORY/${tfVar})\""
      ) credentialMapping
    )}
    ${extraContent}
    EOF
  '';

  # Generate activation script for config change detection
  mkActivationScript =
    {
      serviceName,
      instanceName,
      terraformConfigPath,
    }:
    {
      text = ''
        echo "Checking for ${serviceName} terraform configuration changes..."

        # Create state directory if it doesn't exist
        mkdir -p /var/lib/${serviceName}-${instanceName}-terraform

        # Check if terraform configuration has changed
        CURRENT_CONFIG_HASH=$(sha256sum ${terraformConfigPath} | cut -d' ' -f1)
        LAST_DEPLOY_HASH=$(cat /var/lib/${serviceName}-${instanceName}-terraform/.last-deploy-hash 2>/dev/null || echo "")

        if [ "$CURRENT_CONFIG_HASH" != "$LAST_DEPLOY_HASH" ]; then
          echo "Terraform configuration changed - clearing deploy flag"
          rm -f /var/lib/${serviceName}-${instanceName}-terraform/.deploy-complete
        fi
      '';
      deps = [ "setupSecrets" ];
    };

  # Generate blocking deployment service
  mkDeploymentService =
    {
      serviceName,
      instanceName,
      terraformConfigPath,
      credentialMapping,
      dependencies ? [ ],
      backendType ? "local",
      timeoutSec ? "10m",
      preTerraformScript ? "",
      postTerraformScript ? "",
    }:
    {
      "${serviceName}-terraform-deploy-${instanceName}" = {
        description = "Deploy ${serviceName} terraform configuration synchronously";

        # Run after all dependencies are ready
        after = dependencies;
        requires = dependencies;

        # Make this part of the deployment transaction
        wantedBy = [ "multi-user.target" ];

        # Ensure it only runs once per configuration change
        unitConfig = {
          ConditionPathExists = "!/var/lib/${serviceName}-${instanceName}-terraform/.deploy-complete";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "${serviceName}-${instanceName}-terraform";
          WorkingDirectory = "/var/lib/${serviceName}-${instanceName}-terraform";
          TimeoutStartSec = timeoutSec;
          LoadCredential = lib.mapAttrsToList (
            tfVar: clanVar: "${tfVar}:/run/secrets/vars/${serviceName}-${instanceName}/${clanVar}"
          ) credentialMapping;
        };

        path = [
          pkgs.opentofu
          pkgs.curl
          pkgs.jq
          pkgs.coreutils
          pkgs.util-linux # For flock state locking
        ];

        script = ''
          echo "Checking for ${serviceName} terraform configuration changes during deployment..."

          # State locking implementation for concurrent execution safety
          LOCK_FILE="$STATE_DIRECTORY/.terraform.lock"
          LOCK_TIMEOUT=300  # 5 minutes default

          echo "Acquiring terraform state lock..."

          # Try to acquire exclusive lock with timeout
          exec 200>"$LOCK_FILE"
          if ! ${pkgs.util-linux}/bin/flock -w $LOCK_TIMEOUT -x 200; then
            echo "ERROR: Failed to acquire terraform lock after $LOCK_TIMEOUT seconds"
            echo "Another terraform operation may be in progress"
            echo "Lock file: $LOCK_FILE"

            # Check if lock info file exists and show details
            if [ -f "$LOCK_FILE.info" ]; then
              echo "Lock held by:"
              cat "$LOCK_FILE.info"
            fi

            echo "To force unlock: systemctl stop ${serviceName}-terraform-deploy-${instanceName} && rm -f $LOCK_FILE $LOCK_FILE.info"
            exit 1
          fi

          # Lock acquired - record lock info
          echo "Lock acquired by PID $$"
          cat > "$LOCK_FILE.info" <<EOF
          PID: $$
          Date: $(date -Iseconds)
          Service: ${serviceName}-terraform-deploy-${instanceName}
          User: $(whoami)
          EOF

          # Ensure lock is released on exit
          trap "rm -f '$LOCK_FILE.info'; exec 200>&-" EXIT INT TERM

          # Generate current terraform configuration hash from the build-time config
          CURRENT_CONFIG_HASH=$(sha256sum ${terraformConfigPath} | cut -d' ' -f1)
          LAST_APPLIED_HASH=$(cat .last-deploy-hash 2>/dev/null || echo "")

          if [ "$CURRENT_CONFIG_HASH" != "$LAST_APPLIED_HASH" ]; then
            echo "Terraform configuration changed - applying during deployment..."

            # Copy the new configuration
            cp ${terraformConfigPath} ./main.tf.json

            ${preTerraformScript}

            # Wait for service to be ready (basic check)
            echo "Waiting for ${serviceName} to be ready..."
            for i in {1..60}; do
              if systemctl is-active ${serviceName}.service >/dev/null 2>&1; then
                echo "${serviceName} service is ready"
                break
              fi
              [ $i -eq 60 ] && { echo "ERROR: ${serviceName} not ready for terraform deployment"; exit 1; }
              echo "Waiting for ${serviceName}... (attempt $i/60)"
              sleep 2
            done

            ${
              if backendType == "s3" then
                ''
                  # Load S3/Garage credentials
                  export AWS_ACCESS_KEY_ID=$(cat /var/lib/garage-terraform-${instanceName}/access_key_id)
                  export AWS_SECRET_ACCESS_KEY=$(cat /var/lib/garage-terraform-${instanceName}/secret_access_key)
                  echo "Loaded S3 backend credentials"

                  cat > backend.tf <<'EOF'
                  terraform {
                    backend "s3" {
                      endpoint = "http://127.0.0.1:3900"
                      bucket = "terraform-state"
                      key = "${serviceName}/${instanceName}/terraform.tfstate"
                      region = "garage"
                      skip_credentials_validation = true
                      skip_metadata_api_check = true
                      skip_region_validation = true
                      force_path_style = true
                    }
                  }
                  EOF
                ''
              else
                ''
                  # Local backend
                  cat > backend.tf <<'EOF'
                  terraform {
                    backend "local" {
                      path = "terraform.tfstate"
                    }
                  }
                  EOF
                ''
            }

            # Execute terraform
            echo "Executing terraform during deployment..."
            ${pkgs.opentofu}/bin/tofu init -upgrade -input=false

            set +e
            ${pkgs.opentofu}/bin/tofu plan -var-file=terraform.tfvars -detailed-exitcode -out=tfplan
            PLAN_EXIT=$?
            set -e

            case $PLAN_EXIT in
              0)
                echo "No terraform changes needed"
                ;;
              1)
                echo "ERROR: Terraform plan failed during deployment"
                exit 1
                ;;
              2)
                echo "Applying terraform changes during deployment..."
                ${pkgs.opentofu}/bin/tofu apply -auto-approve tfplan
                echo "Terraform applied successfully during deployment"
                ;;
            esac

            ${postTerraformScript}

            # Mark deployment complete
            echo "$CURRENT_CONFIG_HASH" > .last-deploy-hash
            touch .deploy-complete
            echo "Terraform deployment completed"
          else
            echo "Terraform configuration unchanged"
            touch .deploy-complete
          fi
        '';
      };
    };

  # Generate helper scripts for terraform operations
  mkHelperScripts =
    { serviceName, instanceName }:
    let
      stateDir = "/var/lib/${serviceName}-${instanceName}-terraform";
      lockFile = "${stateDir}/.terraform.lock";
      lockInfoFile = "${stateDir}/.terraform.lock.info";
      deploymentServiceName = "${serviceName}-terraform-deploy-${instanceName}";
    in
    [
      # Unlock script - Force remove terraform state locks
      (pkgs.writeScriptBin "${serviceName}-tf-unlock-${instanceName}" ''
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
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          rm -f "$LOCK_FILE" "$LOCK_INFO"
          echo "Lock removed"
        else
          echo "Cancelled"
        fi
      '')

      # Status script - Show lock status and service health
      (pkgs.writeScriptBin "${serviceName}-tf-status-${instanceName}" ''
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
      (pkgs.writeScriptBin "${serviceName}-tf-apply-${instanceName}" ''
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
      (pkgs.writeScriptBin "${serviceName}-tf-logs-${instanceName}" ''
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

  # Generate Garage bucket init service for S3 backend
  mkGarageInitService =
    { serviceName, instanceName }:
    {
      "garage-terraform-init-${instanceName}" = {
        description = "Initialize Garage bucket for ${serviceName} Terraform";
        after = [ "garage.service" ];
        requires = [ "garage.service" ];
        before = [ "${serviceName}-terraform-deploy-${instanceName}.service" ];
        wantedBy = [ "multi-user.target" ];

        path = [
          pkgs.garage
          pkgs.curl
          pkgs.jq
          pkgs.gawk
          pkgs.gnugrep
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "garage-terraform-${instanceName}";
          WorkingDirectory = "/var/lib/garage-terraform-${instanceName}";
        };

        script = ''
          set -euo pipefail

          # Wait for Garage to be ready
          echo "Waiting for Garage API..."
          for i in {1..30}; do
            if curl -sf http://127.0.0.1:3903/health 2>/dev/null; then
              break
            fi
            sleep 2
          done

          GARAGE="${pkgs.garage}/bin/garage"

          # Create bucket if doesn't exist
          BUCKET_NAME="terraform-state"
          if ! $GARAGE bucket info $BUCKET_NAME 2>/dev/null; then
            echo "Creating $BUCKET_NAME bucket..."
            $GARAGE bucket create $BUCKET_NAME
          fi

          # Create access key if doesn't exist
          KEY_NAME="${serviceName}-${instanceName}-tf"
          if ! $GARAGE key info $KEY_NAME 2>/dev/null; then
            echo "Creating access key..."
            $GARAGE key create $KEY_NAME

            # Grant permissions
            $GARAGE bucket allow $BUCKET_NAME --read --write --owner --key $KEY_NAME
          fi

          # Get credentials - parse text output
          KEY_ID=$($GARAGE key info $KEY_NAME | grep -E '^Key ID:' | awk '{print $3}')
          SECRET=$($GARAGE key info $KEY_NAME --show-secret | grep -E '^Secret key:' | awk '{print $3}')

          # Save credentials
          echo "$KEY_ID" > access_key_id
          echo "$SECRET" > secret_access_key

          echo "Garage bucket and credentials ready"
        '';
      };
    };
}
