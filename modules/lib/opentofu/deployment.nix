{ lib, pkgs }:

rec {
  # Create a blocking deployment pattern for OpenTofu/Terraform
  # This function generates the necessary systemd services and activation scripts
  # for automatic terraform execution during system deployment
  mkBlockingDeployment =
    {
      serviceName, # Name of the service (e.g., "keycloak")
      instanceName, # Instance name (e.g., "production")
      terraformConfigPath, # Path to terraform config JSON
      terraformBackend ? "local", # "local" or "s3"
      blockingDeployment ? true, # Whether to block deployment
      enableDeployment ? true, # Whether to enable the pattern
      dependencies ? [ ], # systemd service dependencies
      credentials ? [ ], # credential files to load
      timeoutStartSec ? "10m", # deployment timeout
      healthCheck ? { }, # health check configuration
      s3Config ? { }, # S3 backend configuration
      extraTerraformVars ? { }, # additional terraform variables
      preTerraformScript ? "", # script to run before terraform
      postTerraformScript ? "", # script to run after terraform
      ...
    }:
    let
      fullServiceName = "${serviceName}-${instanceName}";
      stateDirectory = "${serviceName}-${instanceName}-terraform";
      statePath = "/var/lib/${stateDirectory}";

      # Merge defaults for health check configuration
      healthCheckConfig = {
        enable = true;
        url = "http://localhost:8080/";
        expectedHttpCodes = [
          "200"
          "302"
        ];
        maxAttempts = 60;
        intervalSeconds = 2;
      }
      // healthCheck;

      # Merge defaults for S3 configuration
      s3ConfigMerged = {
        endpoint = "http://127.0.0.1:3900";
        bucket = "terraform-state";
        region = "garage";
        credentialsPath = "/var/lib/garage-terraform-${instanceName}";
      }
      // s3Config;

      # Generate health check script
      healthCheckScript = lib.optionalString healthCheckConfig.enable ''
        echo "Waiting for ${serviceName} to be ready..."
        for i in {1..${toString healthCheckConfig.maxAttempts}}; do
          HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' ${healthCheckConfig.url} 2>/dev/null || echo "000")
          ${
            lib.concatMapStringsSep " || " (
              code: ''[ "$HTTP_CODE" = "${code}" ]''
            ) healthCheckConfig.expectedHttpCodes
          } && {
            echo "${serviceName} is ready (HTTP $HTTP_CODE)"
            break
          }
          [ $i -eq ${toString healthCheckConfig.maxAttempts} ] && {
            echo "ERROR: ${serviceName} not ready for terraform deployment";
            exit 1;
          }
          echo "Waiting for ${serviceName}... (attempt $i/${toString healthCheckConfig.maxAttempts})"
          sleep ${toString healthCheckConfig.intervalSeconds}
        done
      '';

      # Generate backend configuration script
      backendConfigScript =
        if terraformBackend == "s3" then
          ''
            export AWS_ACCESS_KEY_ID=$(cat ${s3ConfigMerged.credentialsPath}/access_key_id)
            export AWS_SECRET_ACCESS_KEY=$(cat ${s3ConfigMerged.credentialsPath}/secret_access_key)
            echo "Loaded S3 credentials"

            cat > backend.tf <<'EOF'
            terraform {
              backend "s3" {
                endpoint = "${s3ConfigMerged.endpoint}"
                bucket = "${s3ConfigMerged.bucket}"
                key = "${serviceName}/${instanceName}/terraform.tfstate"
                region = "${s3ConfigMerged.region}"
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
            cat > backend.tf <<'EOF'
            terraform {
              backend "local" {
                path = "terraform.tfstate"
              }
            }
            EOF
          '';

      # Generate terraform variables script
      terraformVarsScript = ''
        cat > terraform.tfvars <<EOF
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (key: value: ''${key} = "${value}"'') extraTerraformVars
        )}
        EOF
      '';

    in
    lib.mkIf enableDeployment {
      # Activation script to detect configuration changes
      system.activationScripts."${serviceName}-terraform-reset-${instanceName}" = {
        text = ''
          # Create state directory if it doesn't exist
          mkdir -p ${statePath}

          # Check if terraform configuration has changed
          CURRENT_CONFIG_HASH=$(sha256sum ${terraformConfigPath} | cut -d' ' -f1)
          LAST_DEPLOY_HASH=$(cat ${statePath}/.last-deploy-hash 2>/dev/null || echo "")

          if [ "$CURRENT_CONFIG_HASH" != "$LAST_DEPLOY_HASH" ]; then
            echo "Terraform configuration changed for ${fullServiceName} - clearing deploy flag"
            rm -f ${statePath}/.deploy-complete
          fi
        '';
        deps = [ "setupSecrets" ];
      };

      # Oneshot deployment service
      systemd.services."${serviceName}-terraform-deploy-${instanceName}" = {
        description = "Deploy ${serviceName} terraform configuration synchronously";

        # Dependencies
        after = dependencies;
        requires = dependencies;

        # Make this part of the deployment transaction if blocking is enabled
        wantedBy = lib.optional blockingDeployment "multi-user.target";

        # Ensure it only runs once per configuration change
        unitConfig = {
          ConditionPathExists = "!${statePath}/.deploy-complete";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = stateDirectory;
          WorkingDirectory = statePath;
          TimeoutStartSec = timeoutStartSec;
          LoadCredential = credentials;
        };

        path = with pkgs; [
          opentofu
          curl
          jq
          coreutils
          gnused
          gawk
        ];

        script = ''
          set -euo pipefail

          echo "Checking for ${serviceName} terraform configuration changes during deployment..."

          # Generate current terraform configuration hash from the build-time config
          CURRENT_CONFIG_HASH=$(sha256sum ${terraformConfigPath} | cut -d' ' -f1)
          LAST_APPLIED_HASH=$(cat .last-deploy-hash 2>/dev/null || echo "")

          if [ "$CURRENT_CONFIG_HASH" != "$LAST_APPLIED_HASH" ]; then
            echo "Terraform configuration changed for ${fullServiceName} - applying during deployment..."

            # Copy the new configuration
            cp ${terraformConfigPath} ./main.tf.json

            # Generate terraform variables
            ${terraformVarsScript}

            # Run pre-terraform script
            ${preTerraformScript}

            # Health check
            ${healthCheckScript}

            # Load backend credentials and configure backend
            ${backendConfigScript}

            # Execute terraform
            echo "Executing terraform during deployment for ${fullServiceName}..."
            tofu init -upgrade -input=false

            set +e
            tofu plan -var-file=terraform.tfvars -detailed-exitcode -out=tfplan
            PLAN_EXIT=$?
            set -e

            case $PLAN_EXIT in
              0)
                echo "No terraform changes needed for ${fullServiceName}"
                ;;
              1)
                echo "ERROR: Terraform plan failed during deployment for ${fullServiceName}"
                exit 1
                ;;
              2)
                echo "Applying terraform changes during deployment for ${fullServiceName}..."
                tofu apply -auto-approve tfplan
                echo "Terraform applied successfully during deployment for ${fullServiceName}"
                ;;
            esac

            # Run post-terraform script
            ${postTerraformScript}

            # Mark deployment complete
            echo "$CURRENT_CONFIG_HASH" > .last-deploy-hash
            touch .deploy-complete
            echo "Terraform deployment completed for ${fullServiceName}"
          else
            echo "Terraform configuration unchanged for ${fullServiceName}"
            touch .deploy-complete
          fi
        '';
      };

      # Helper commands for management
      environment.systemPackages = with pkgs; [
        (writeScriptBin "${serviceName}-tf-status-${instanceName}" ''
          #!${pkgs.bash}/bin/bash
          echo "=== Terraform Status for ${fullServiceName} ==="
          echo "State directory: ${statePath}"
          echo "Config file: ${terraformConfigPath}"
          echo ""

          if [ -f "${statePath}/.deploy-complete" ]; then
            echo "Deploy status: COMPLETE"
            if [ -f "${statePath}/.last-deploy-hash" ]; then
              echo "Last deploy hash: $(cat ${statePath}/.last-deploy-hash)"
            fi
          else
            echo "Deploy status: PENDING"
          fi

          echo ""
          echo "=== Service Status ==="
          systemctl status --no-pager -l ${serviceName}-terraform-deploy-${instanceName}.service || true
        '')

        (writeScriptBin "${serviceName}-tf-deploy-${instanceName}" ''
          #!${pkgs.bash}/bin/bash
          echo "Triggering terraform deployment for ${fullServiceName}..."

          # Remove deploy complete flag to force redeployment
          sudo rm -f ${statePath}/.deploy-complete

          # Start the deployment service
          sudo systemctl start ${serviceName}-terraform-deploy-${instanceName}.service

          # Follow the logs
          journalctl -u ${serviceName}-terraform-deploy-${instanceName}.service -f
        '')

        (writeScriptBin "${serviceName}-tf-reset-${instanceName}" ''
          #!${pkgs.bash}/bin/bash
          echo "Resetting terraform deployment state for ${fullServiceName}..."

          read -p "This will force re-deployment on next activation. Continue? (y/N) " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo rm -f ${statePath}/.deploy-complete ${statePath}/.last-deploy-hash
            echo "Deployment state reset for ${fullServiceName}"
          else
            echo "Cancelled"
          fi
        '')
      ];
    };

  # Convenience function for simple cases with common defaults
  mkSimpleBlockingDeployment =
    {
      serviceName,
      instanceName,
      terraformConfigPath,
      dependencies ? [ ],
      credentials ? [ ],
      extraTerraformVars ? { },
    }:
    mkBlockingDeployment {
      inherit
        serviceName
        instanceName
        terraformConfigPath
        dependencies
        credentials
        extraTerraformVars
        ;
    };

  # Function to create S3-backed deployment
  mkS3BlockingDeployment =
    {
      serviceName,
      instanceName,
      terraformConfigPath,
      dependencies ? [ ],
      credentials ? [ ],
      extraTerraformVars ? { },
      s3Config ? { },
    }:
    mkBlockingDeployment {
      inherit
        serviceName
        instanceName
        terraformConfigPath
        dependencies
        credentials
        extraTerraformVars
        s3Config
        ;
      terraformBackend = "s3";
    };
}
