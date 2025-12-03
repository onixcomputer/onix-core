# Enhanced OpenTofu Library - Pure functions for clan services with terranix support
{ lib, pkgs }:

let
  # Import terranix utilities
  terranix = import ./terranix.nix { inherit lib pkgs; };
in
{
  # Re-export terranix utilities for convenience
  inherit (terranix)
    evalTerranixModule
    generateTerranixJson
    validateTerranixConfig
    mkTerranixDeploymentService
    testTerranixModule
    introspectTerranixModule
    mkTerranixModule
    jsonToTerranixModule
    formatTerranixError
    terranixModuleType
    terranixConfigType
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

  # Generate activation script for config change detection
  mkActivationScript =
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
      # Determine the config path to use (same logic as mkDeploymentService)
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
          throw "mkActivationScript: Either terraformConfigPath or terranixModule must be provided";
    in
    {
      text = ''
        echo "Checking for ${serviceName} terraform configuration changes..."

        # Create state directory if it doesn't exist
        mkdir -p /var/lib/${serviceName}-${instanceName}-terraform

        # Check if terraform configuration has changed
        CURRENT_CONFIG_HASH=$(sha256sum ${configPath} | cut -d' ' -f1)
        LAST_DEPLOY_HASH=$(cat /var/lib/${serviceName}-${instanceName}-terraform/.last-deploy-hash 2>/dev/null || echo "")

        if [ "$CURRENT_CONFIG_HASH" != "$LAST_DEPLOY_HASH" ]; then
          echo "Terraform configuration changed - clearing deploy flag"
          rm -f /var/lib/${serviceName}-${instanceName}-terraform/.deploy-complete
        fi
      '';
      deps = [ "setupSecrets" ];
    };

  # Enhanced deployment service that supports both JSON configs and terranix modules
  mkDeploymentService =
    {
      serviceName,
      instanceName,
      # Traditional terraform config path (for backward compatibility)
      terraformConfigPath ? null,
      # New terranix module support
      terranixModule ? null,
      terranixModuleArgs ? { },
      terranixValidate ? true,
      terranixDebug ? false,
      # Credentials and deployment options
      credentialMapping,
      dependencies ? [ ],
      backendType ? "local",
      timeoutSec ? "10m",
      preTerraformScript ? "",
      postTerraformScript ? "",
    }:
    let
      # Determine the terraform configuration to use
      configPath =
        if terranixModule != null then
          # Generate config from terranix module
          terranix.generateTerranixJson {
            module = terranixModule;
            moduleArgs = terranixModuleArgs;
            fileName = "${serviceName}-terranix-${instanceName}.json";
            validate = terranixValidate;
            debug = terranixDebug;
          }
        else if terraformConfigPath != null then
          # Use provided config path
          terraformConfigPath
        else
          throw "mkDeploymentService: Either terraformConfigPath or terranixModule must be provided";

      # Enhanced pre-terraform script with terranix info
      enhancedPreScript =
        preTerraformScript
        + lib.optionalString (terranixModule != null) ''
          echo "Using terranix-generated configuration"
          ${lib.optionalString terranixDebug ''
            echo "Terranix debug mode enabled"
            echo "Generated configuration preview:"
            head -20 ${configPath} || true
          ''}
        '';

    in
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
          # Prevent rapid restart loops on failure
          Restart = "no";
          RestartSec = "30s";
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
          if ! ${pkgs.util-linux}/bin/flock -w "$LOCK_TIMEOUT" -x 200; then
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
          CURRENT_CONFIG_HASH=$(sha256sum ${configPath} | cut -d' ' -f1)
          LAST_APPLIED_HASH=$(cat .last-deploy-hash 2>/dev/null || echo "")

          if [ "$CURRENT_CONFIG_HASH" != "$LAST_APPLIED_HASH" ]; then
            echo "Terraform configuration changed - applying during deployment..."

            # Copy the new configuration
            cp ${configPath} ./main.tf.json

            ${enhancedPreScript}

            # Comprehensive readiness check with health probes
            echo "=== ${serviceName} Readiness Verification ==="
            echo "Timestamp: $(date -Iseconds)"

            # Phase 1: Wait for systemd service to be active
            echo "Phase 1: Waiting for systemd service..."
            for i in {1..60}; do
              if systemctl is-active ${serviceName}.service >/dev/null 2>&1; then
                echo "${serviceName} systemd service is active"
                break
              fi
              [ "$i" -eq 60 ] && { echo "ERROR: ${serviceName} service failed to start"; exit 1; }
              echo "Waiting for ${serviceName} service... (attempt $i/60)"
              sleep 2
            done

            # Phase 2: Wait for health endpoints (Keycloak-specific)
            if [ "${serviceName}" = "keycloak" ]; then
              echo "Phase 2: Waiting for Keycloak health endpoints..."
              HEALTH_CHECK_MAX_ATTEMPTS=90  # 3 minutes

              for i in $(seq 1 $HEALTH_CHECK_MAX_ATTEMPTS); do
                # Check startup probe
                if curl -sf http://localhost:9000/management/health/started >/dev/null 2>&1; then
                  echo "✓ Startup probe passed"

                  # Check readiness probe
                  if curl -sf http://localhost:9000/management/health/ready >/dev/null 2>&1; then
                    echo "✓ Readiness probe passed"

                    # Check OIDC endpoint
                    if curl -sf http://localhost:8080/realms/master/protocol/openid-connect/certs >/dev/null 2>&1; then
                      echo "✓ OIDC endpoints accessible"
                      echo "✓ ${serviceName} is fully ready for terraform operations"
                      break
                    else
                      echo "OIDC endpoints not yet accessible (attempt $i/$HEALTH_CHECK_MAX_ATTEMPTS)"
                    fi
                  else
                    echo "Readiness probe failed (attempt $i/$HEALTH_CHECK_MAX_ATTEMPTS)"
                  fi
                else
                  echo "Startup probe failed (attempt $i/$HEALTH_CHECK_MAX_ATTEMPTS)"
                fi

                [ "$i" -eq $HEALTH_CHECK_MAX_ATTEMPTS ] && {
                  echo "ERROR: ${serviceName} health checks failed after $((HEALTH_CHECK_MAX_ATTEMPTS * 2)) seconds"
                  echo "Service status:"
                  systemctl status ${serviceName}.service --no-pager
                  exit 1
                }

                sleep 2
              done

              # Additional stabilization wait for authentication subsystem
              echo "Phase 3: Authentication subsystem stabilization..."
              sleep 10
            else
              # Non-Keycloak services use basic readiness
              echo "Phase 2: Basic service readiness wait..."
              sleep 5
            fi

            echo "=== ${serviceName} Ready for Terraform Operations ==="

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
            # Capture terraform output to filter verbose JSON dumps
            TERRAFORM_PLAN_OUTPUT=$(${pkgs.opentofu}/bin/tofu plan -var-file=terraform.tfvars -detailed-exitcode -out=tfplan 2>&1)
            PLAN_EXIT=$?
            set -e

            case "$PLAN_EXIT" in
              0)
                echo "No terraform changes needed"
                ;;
              1)
                echo "ERROR: Terraform plan failed during deployment"
                # Extract clean error messages, filter out JSON dumps
                echo "$TERRAFORM_PLAN_OUTPUT" | grep -E "(Error:|Warning:|│)" | grep -v '{"output":' | head -10
                exit 1
                ;;
              2)
                echo "Applying terraform changes during deployment..."
                echo "Plan summary:"
                echo "$TERRAFORM_PLAN_OUTPUT" | grep -E "(will be created|will be modified|will be destroyed)" | head -5

                set +e
                TERRAFORM_APPLY_OUTPUT=$(${pkgs.opentofu}/bin/tofu apply -auto-approve tfplan 2>&1)
                APPLY_EXIT=$?
                set -e

                if [ $APPLY_EXIT -ne 0 ]; then
                  echo "ERROR: Terraform apply failed"
                  # Extract clean error messages, filter out JSON dumps
                  echo "$TERRAFORM_APPLY_OUTPUT" | grep -E "(Error:|Warning:|│)" | grep -v '{"output":' | head -10
                  exit 1
                fi

                echo "✓ Terraform apply completed successfully"
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
        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
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
    {
      serviceName,
      instanceName,
      config ? null,
    }:
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

          # Load garage credentials if config is provided
          LoadCredential = lib.optionals (config != null) (
            lib.optionals (config.clan.core.vars.generators ? "garage") [
              "admin_token:${config.clan.core.vars.generators.garage.files.admin_token.path}"
            ]
            ++ lib.optionals (config.clan.core.vars.generators ? "garage-shared") [
              "rpc_secret:${config.clan.core.vars.generators.garage-shared.files.rpc_secret.path}"
            ]
          );
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

          # Load garage credentials if available
          if [ -f "$CREDENTIALS_DIRECTORY/admin_token" ]; then
            export GARAGE_ADMIN_TOKEN=$(cat $CREDENTIALS_DIRECTORY/admin_token)
          fi

          if [ -f "$CREDENTIALS_DIRECTORY/rpc_secret" ]; then
            export GARAGE_RPC_SECRET=$(cat $CREDENTIALS_DIRECTORY/rpc_secret)
          fi

          GARAGE="${pkgs.garage}/bin/garage"

          # Create bucket if doesn't exist
          BUCKET_NAME="terraform-state"
          if ! "$GARAGE" bucket info "$BUCKET_NAME" 2>/dev/null; then
            echo "Creating $BUCKET_NAME bucket..."
            "$GARAGE" bucket create "$BUCKET_NAME"
          fi

          # Create access key if doesn't exist
          KEY_NAME="${serviceName}-${instanceName}-tf"
          if ! "$GARAGE" key info "$KEY_NAME" 2>/dev/null; then
            echo "Creating access key..."
            "$GARAGE" key create "$KEY_NAME"

            # Grant permissions
            "$GARAGE" bucket allow "$BUCKET_NAME" --read --write --owner --key "$KEY_NAME"
          fi

          # Get credentials - parse text output
          KEY_ID=$("$GARAGE" key info "$KEY_NAME" | grep -E '^Key ID:' | awk '{print $3}')
          SECRET=$("$GARAGE" key info "$KEY_NAME" --show-secret | grep -E '^Secret key:' | awk '{print $3}')

          # Save credentials
          echo "$KEY_ID" > access_key_id
          echo "$SECRET" > secret_access_key

          echo "Garage bucket and credentials ready"
        '';
      };
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
