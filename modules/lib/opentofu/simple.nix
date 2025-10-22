# Simple OpenTofu Library - Pure functions without config dependencies
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
        ];

        script = ''
          echo "Checking for ${serviceName} terraform configuration changes during deployment..."

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
}
