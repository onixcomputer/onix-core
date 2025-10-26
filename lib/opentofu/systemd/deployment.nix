# SystemD Deployment Service Generation
# Modular deployment service creation with composable functions
{ lib, pkgs }:

let
  pure = import ../lib-pure.nix { inherit lib; };
  healthChecks = import ./health-checks.nix { inherit lib; };
in

rec {
  # Generate basic systemd service configuration
  mkServiceConfig =
    {
      serviceName,
      instanceName,
      dependencies ? [ ],
      timeoutSec ? "10m",
      credentialMapping,
    }:
    {
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
    };

  # Generate main deployment script logic
  mkDeploymentScript =
    {
      serviceName,
      instanceName,
      configPath,
      backendType ? "local",
      preTerraformScript ? "",
      postTerraformScript ? "",
      terranixDebug ? false,
      terranixModule ? null,
    }:
    let
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

      # Generate backend configuration
      backendConfig =
        if backendType == "s3" then
          pure.generateS3BackendConfig { inherit serviceName instanceName; }
        else
          pure.generateLocalBackendConfig;

      # Generate backend script
      backendScript =
        if backendType == "s3" then
          ''
            # Load S3/Garage credentials
            export AWS_ACCESS_KEY_ID=$(cat /var/lib/garage-terraform-${instanceName}/access_key_id)
            export AWS_SECRET_ACCESS_KEY=$(cat /var/lib/garage-terraform-${instanceName}/secret_access_key)
            echo "Loaded S3 backend credentials"

            cat > backend.tf <<'EOF'
            ${backendConfig}
            EOF
          ''
        else
          ''
            # Local backend
            cat > backend.tf <<'EOF'
            ${backendConfig}
            EOF
          '';

    in
    ''
      echo "Checking for ${serviceName} terraform configuration changes during deployment..."

      # Generate current terraform configuration hash from the build-time config
      CURRENT_CONFIG_HASH=$(sha256sum ${configPath} | cut -d' ' -f1)
      LAST_APPLIED_HASH=$(cat .last-deploy-hash 2>/dev/null || echo "")

      if [ "$CURRENT_CONFIG_HASH" != "$LAST_APPLIED_HASH" ]; then
        echo "Terraform configuration changed - applying during deployment..."

        # Copy the new configuration
        cp ${configPath} ./main.tf.json

        ${enhancedPreScript}

        # Comprehensive readiness check with health probes
        ${healthChecks.generateHealthChecks serviceName}

        ${backendScript}

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

  # Generate state locking script
  mkLockingScript =
    {
      serviceName,
      instanceName,
    }:
    let
      lockFile = "$STATE_DIRECTORY/.terraform.lock";
      lockInfoFile = "$STATE_DIRECTORY/.terraform.lock.info";
      deploymentServiceName = "${serviceName}-terraform-deploy-${instanceName}";
    in
    ''
      # State locking implementation for concurrent execution safety
      LOCK_FILE="${lockFile}"
      LOCK_TIMEOUT=300  # 5 minutes default

      echo "Acquiring terraform state lock..."

      # Try to acquire exclusive lock with timeout
      exec 200>"$LOCK_FILE"
      if ! ${pkgs.util-linux}/bin/flock -w "$LOCK_TIMEOUT" -x 200; then
        echo "ERROR: Failed to acquire terraform lock after $LOCK_TIMEOUT seconds"
        echo "Another terraform operation may be in progress"
        echo "Lock file: $LOCK_FILE"

        # Check if lock info file exists and show details
        if [ -f "${lockInfoFile}" ]; then
          echo "Lock held by:"
          cat "${lockInfoFile}"
        fi

        echo "To force unlock: systemctl stop ${deploymentServiceName} && rm -f $LOCK_FILE ${lockInfoFile}"
        exit 1
      fi

      # Lock acquired - record lock info
      echo "Lock acquired by PID $$"
      cat > "${lockInfoFile}" <<EOF
      PID: $$
      Date: $(date -Iseconds)
      Service: ${deploymentServiceName}
      User: $(whoami)
      EOF

      # Ensure lock is released on exit
      trap "rm -f '${lockInfoFile}'; exec 200>&-" EXIT INT TERM
    '';

  # Main function to create deployment service
  mkTerranixInfrastructure =
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
      # Import terranix utilities if needed
      terranix = import ../terranix.nix { inherit lib pkgs; };

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
          throw ''
            mkTerranixInfrastructure: No terraform configuration provided

            You must provide either a terranix module (recommended) or a JSON config path.

            Terranix approach (recommended):
            opentofu.mkTerranixInfrastructure {
              serviceName = "postgres";
              instanceName = "prod";
              terranixModule = ./postgres-config.nix;  # ← Nix file with terraform config
              credentialMapping = { admin_password = "postgres_password"; };
            }

            JSON approach (legacy):
            opentofu.mkTerranixInfrastructure {
              serviceName = "postgres";
              instanceName = "prod";
              terraformConfigPath = ./terraform-config.json;  # ← JSON terraform file
              credentialMapping = { admin_password = "postgres_password"; };
            }

            Terranix module example (./postgres-config.nix):
            { settings }: {
              terraform.required_providers.postgresql = { source = "cyrilgdn/postgresql"; };
              provider.postgresql = { host = settings.host; };
              resource.postgresql_database.mydb = { name = settings.database; };
            }

            Need help getting started? Try: opentofu.mkTerranixService instead -
            it provides a complete service with helper scripts and activation.
          '';

      # Use the deployment module's own functions by calling them directly
      serviceConfigResult = mkServiceConfig {
        inherit
          serviceName
          instanceName
          dependencies
          timeoutSec
          credentialMapping
          ;
      };

      lockingScriptResult = mkLockingScript {
        inherit serviceName instanceName;
      };

      deploymentScriptResult = mkDeploymentScript {
        inherit
          serviceName
          instanceName
          configPath
          backendType
          preTerraformScript
          postTerraformScript
          terranixDebug
          terranixModule
          ;
      };

    in
    {
      "${serviceName}-terraform-deploy-${instanceName}" = serviceConfigResult // {
        script = lockingScriptResult + "\n\n" + deploymentScriptResult;
      };
    };
}
