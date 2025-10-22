# Generic OpenTofu backend management system
# Extracted from keycloak module and generalized for reuse across all clan services
{ lib, pkgs, ... }:

let
  inherit (lib)
    types
    mkOption
    mkIf
    optionalAttrs
    optionals
    optionalString
    ;

  # Backend type definitions
  backendType = types.enum [
    "local"
    "s3"
    "garage"
  ];

  # Backend configuration options
  backendOptions = {
    type = mkOption {
      type = backendType;
      default = "local";
      description = "OpenTofu state backend type";
      example = "garage";
    };

    bucket = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "S3/Garage bucket name for state storage";
      example = "terraform-state";
    };

    endpoint = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "S3/Garage endpoint URL";
      example = "http://127.0.0.1:3900";
    };

    region = mkOption {
      type = types.str;
      default = "garage";
      description = "S3/Garage region";
    };

    keyPrefix = mkOption {
      type = types.str;
      default = "";
      description = "Key prefix for state file organization";
      example = "services/keycloak";
    };

    garageCredentials = {
      adminTokenFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to Garage admin token file";
      };

      rpcSecretFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to Garage RPC secret file";
      };
    };

    s3Credentials = {
      accessKeyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to S3 access key file";
      };

      secretKeyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to S3 secret key file";
      };
    };

    lockTimeout = mkOption {
      type = types.int;
      default = 300;
      description = "Terraform state lock timeout in seconds";
    };
  };

  # Generate backend configuration based on type
  generateBackendConfig =
    backend: instanceName: _backendDir:
    if backend.type == "local" then
      ''
        terraform {
          backend "local" {
            path = "terraform.tfstate"
          }
        }
      ''
    else if backend.type == "s3" || backend.type == "garage" then
      let
        bucketName = backend.bucket or "terraform-state";
        keyPath =
          if backend.keyPrefix != "" then
            "${backend.keyPrefix}/${instanceName}/terraform.tfstate"
          else
            "${instanceName}/terraform.tfstate";
        endpoint = backend.endpoint or (if backend.type == "garage" then "http://127.0.0.1:3900" else null);
      in
      ''
        terraform {
          backend "s3" {
            ${optionalString (endpoint != null) ''endpoint = "${endpoint}"''}
            bucket = "${bucketName}"
            key = "${keyPath}"
            region = "${backend.region}"

            ${optionalString (backend.type == "garage") ''
              skip_credentials_validation = true
              skip_metadata_api_check = true
              skip_region_validation = true
              force_path_style = true
            ''}
          }
        }
      ''
    else
      throw "Unsupported backend type: ${backend.type}";

  # Generate Garage bucket initialization service
  generateGarageBucketService = serviceName: instanceName: backend: {
    description = "Initialize Garage bucket for ${serviceName} OpenTofu";
    after = [ "garage.service" ];
    requires = [ "garage.service" ];
    before = [ "${serviceName}-terraform-${instanceName}.service" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [
      garage
      curl
      jq
      gawk
      gnugrep
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "garage-terraform-${instanceName}";
      WorkingDirectory = "/var/lib/garage-terraform-${instanceName}";

      LoadCredential =
        optionals (backend.garageCredentials.adminTokenFile != null) [
          "admin_token:${backend.garageCredentials.adminTokenFile}"
        ]
        ++ optionals (backend.garageCredentials.rpcSecretFile != null) [
          "rpc_secret:${backend.garageCredentials.rpcSecretFile}"
        ];
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

      # Load credentials
      if [ -f "$CREDENTIALS_DIRECTORY/admin_token" ]; then
        export GARAGE_ADMIN_TOKEN=$(cat $CREDENTIALS_DIRECTORY/admin_token)
      fi

      if [ -f "$CREDENTIALS_DIRECTORY/rpc_secret" ]; then
        export GARAGE_RPC_SECRET=$(cat $CREDENTIALS_DIRECTORY/rpc_secret)
      fi

      GARAGE="${pkgs.garage}/bin/garage"
      BUCKET_NAME="${backend.bucket or "terraform-state"}"

      # Create bucket if doesn't exist
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

  # Generate credential loading script for S3/Garage backends
  generateCredentialLoader =
    backend: instanceName:
    if backend.type == "garage" then
      ''
        # Load Garage credentials
        if [ -f "/var/lib/garage-terraform-${instanceName}/access_key_id" ]; then
          export AWS_ACCESS_KEY_ID=$(cat /var/lib/garage-terraform-${instanceName}/access_key_id)
          export AWS_SECRET_ACCESS_KEY=$(cat /var/lib/garage-terraform-${instanceName}/secret_access_key)
          echo "Loaded Garage credentials for state backend"
        else
          echo "ERROR: Garage credentials not found at /var/lib/garage-terraform-${instanceName}/"
          exit 1
        fi
      ''
    else if backend.type == "s3" then
      ''
        # Load S3 credentials
        ${optionalString (backend.s3Credentials.accessKeyFile != null) ''
          export AWS_ACCESS_KEY_ID=$(cat ${backend.s3Credentials.accessKeyFile})
        ''}
        ${optionalString (backend.s3Credentials.secretKeyFile != null) ''
          export AWS_SECRET_ACCESS_KEY=$(cat ${backend.s3Credentials.secretKeyFile})
        ''}
        echo "Loaded S3 credentials for state backend"
      ''
    else
      "# Local backend - no credentials needed";

  # Configuration change detection utilities
  generateConfigChangeDetection = serviceName: instanceName: terraformConfigPath: _backend: {
    activationScript = {
      text = ''
        # Create state directory if it doesn't exist
        mkdir -p /var/lib/${serviceName}-${instanceName}-terraform

        # Check if terraform configuration has changed
        CURRENT_CONFIG_HASH=$(sha256sum ${terraformConfigPath} | cut -d' ' -f1)
        LAST_DEPLOY_HASH=$(cat /var/lib/${serviceName}-${instanceName}-terraform/.last-deploy-hash 2>/dev/null || echo "")

        if [ "$CURRENT_CONFIG_HASH" != "$LAST_DEPLOY_HASH" ]; then
          echo "Terraform configuration changed - clearing deploy flag"
          rm -f /var/lib/${serviceName}-${instanceName}-terraform/.deploy-complete
          touch /var/lib/${serviceName}-${instanceName}-terraform/.needs-apply
        fi
      '';
      deps = [ "setupSecrets" ];
    };

    hashScript = ''
      # Generate current terraform configuration hash from the build-time config
      CURRENT_CONFIG_HASH=$(sha256sum ${terraformConfigPath} | cut -d' ' -f1)
      LAST_APPLIED_HASH=$(cat .last-deploy-hash 2>/dev/null || echo "")

      if [ "$CURRENT_CONFIG_HASH" != "$LAST_APPLIED_HASH" ]; then
        echo "Terraform configuration changed - applying during deployment..."
        return 0
      else
        echo "Terraform configuration unchanged"
        return 1
      fi
    '';
  };

  # Generate systemd service dependencies based on backend type
  generateServiceDeps =
    backend: instanceName:
    if backend.type == "garage" then
      {
        after = [ "garage-terraform-init-${instanceName}.service" ];
        requires = [ "garage-terraform-init-${instanceName}.service" ];
      }
    else if backend.type == "s3" then
      {
        after = [ ];
        requires = [ ];
      }
    else
      {
        after = [ ];
        requires = [ ];
      };

  # Generate helper command scripts for terraform management
  generateHelperCommands =
    serviceName: instanceName: _backend: with pkgs; [
      (writeScriptBin "${serviceName}-tf-unlock-${instanceName}" ''
        #!${bash}/bin/bash
        LOCK_FILE="/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock"
        LOCK_INFO="/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock.info"

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

      (writeScriptBin "${serviceName}-tf-status-${instanceName}" ''
        #!${bash}/bin/bash
        LOCK_FILE="/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock"
        LOCK_INFO="/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock.info"

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
        echo "=== Terraform Service Status ==="
        systemctl status --no-pager -l ${serviceName}-terraform-${instanceName}.service || true
      '')

      (writeScriptBin "${serviceName}-tf-apply-${instanceName}" ''
        #!${bash}/bin/bash
        echo "Triggering terraform apply for ${serviceName}-${instanceName}..."
        systemctl start ${serviceName}-terraform-${instanceName}.service

        # Follow the logs
        journalctl -u ${serviceName}-terraform-${instanceName}.service -f
      '')
    ];

in
{
  # Main function to generate complete OpenTofu backend system
  # Usage: generateOpenTofuBackend { serviceName, instanceName, backend, terraformConfig, autoApply, credentialFiles }
  generateOpenTofuBackend =
    {
      serviceName,
      instanceName,
      backend,
      terraformConfig,
      autoApply ? false,
      credentialFiles ? [ ],
      additionalDeps ? [ ],
      waitForService ? null,
      waitScript ? "",
      terraformVars ? { },
      terraformVarsScript ? "",
    }:
    let
      backendConfig =
        generateBackendConfig backend instanceName
          "/var/lib/${serviceName}-${instanceName}-terraform";
      serviceDeps = generateServiceDeps backend instanceName;
      changeDetection = generateConfigChangeDetection serviceName instanceName terraformConfig backend;
      credentialLoader = generateCredentialLoader backend instanceName;
      helperCommands = generateHelperCommands serviceName instanceName backend;

      # Generate terraform variables file content
      generateTerraformVars = ''
        cat > terraform.tfvars <<EOF
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: value:
            if builtins.isString value then
              ''${name} = "${value}"''
            else if builtins.isBool value then
              ''${name} = ${if value then "true" else "false"}''
            else if builtins.isInt value then
              ''${name} = ${toString value}''
            else
              ''${name} = "${toString value}"''
          ) terraformVars
        )}
        EOF

        ${terraformVarsScript}
      '';

      # Core terraform execution script
      terraformExecutionScript = ''
        set -euo pipefail

        echo "Starting OpenTofu for ${serviceName} ${instanceName}"

        # Wait for dependencies
        ${waitScript}
        ${optionalString (waitForService != null) ''
          echo "Waiting for ${waitForService}..."
          for i in {1..60}; do
            if systemctl is-active ${waitForService} >/dev/null 2>&1; then
              echo "${waitForService} is ready"
              break
            fi
            [ $i -eq 60 ] && { echo "Timeout waiting for ${waitForService}"; exit 1; }
            echo "Waiting... (attempt $i/60)"
            sleep 5
          done
        ''}

        # Load backend credentials
        ${credentialLoader}

        # Generate backend configuration
        cat > backend.tf <<'EOF'
        ${backendConfig}
        EOF

        # Clean up any old terraform files to prevent conflicts
        echo "Cleaning up old terraform files..."
        rm -f simple-main.tf.json *.tf.json.backup main.tf.json 2>/dev/null || true

        # Copy pre-generated Terraform configuration
        echo "Using Terraform configuration for ${instanceName}..."
        cp ${terraformConfig} ./main.tf.json
        echo "Loaded main.tf.json ($(wc -c < main.tf.json) bytes)"

        # Generate tfvars
        ${generateTerraformVars}

        # Initialize Terraform
        ${optionalString (backend.type == "s3" || backend.type == "garage") ''
          echo "Initializing Terraform with ${backend.type} backend..."
          tofu init -reconfigure -upgrade -input=false
        ''}
        ${optionalString (backend.type == "local") ''
          if [ ! -d .terraform ]; then
            echo "Initializing Terraform..."
            tofu init -upgrade -input=false
          fi
        ''}

        # Check configuration hash for idempotency
        CONFIG_HASH=$(sha256sum main.tf.json terraform.tfvars 2>/dev/null | sha256sum | cut -d' ' -f1)
        LAST_HASH=""

        if [ -f .last-config-hash ]; then
          LAST_HASH=$(cat .last-config-hash)
        fi

        if [ "$CONFIG_HASH" = "$LAST_HASH" ]; then
          echo "Configuration unchanged - checking drift..."
        fi

        # Plan
        echo "Planning changes..."
        set +e
        tofu plan -var-file=terraform.tfvars -detailed-exitcode -out=tfplan
        PLAN_EXIT=$?
        set -e

        case $PLAN_EXIT in
          0)
            echo "No changes needed"
            echo "$CONFIG_HASH" > .last-config-hash
            exit 0
            ;;
          1)
            echo "Plan failed"
            exit 1
            ;;
          2)
            echo "Changes detected - applying..."
            ;;
        esac

        # Apply
        echo "Applying configuration..."
        tofu apply -auto-approve tfplan
        echo "$CONFIG_HASH" > .last-config-hash

        echo "OpenTofu completed successfully"
      '';

      # Generate state locking wrapper

    in
    {
      # Backend-specific services
      services = optionalAttrs (backend.type == "garage" && autoApply) {
        "garage-terraform-init-${instanceName}" =
          generateGarageBucketService serviceName instanceName
            backend;
      };

      # Deployment service for synchronous execution during deployment
      deployService = mkIf autoApply {
        description = "Deploy ${serviceName} terraform configuration synchronously";

        after = additionalDeps ++ serviceDeps.after;
        requires = additionalDeps ++ serviceDeps.requires;
        wantedBy = [ "multi-user.target" ];

        unitConfig = {
          ConditionPathExists = "!/var/lib/${serviceName}-${instanceName}-terraform/.deploy-complete";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "${serviceName}-${instanceName}-terraform";
          WorkingDirectory = "/var/lib/${serviceName}-${instanceName}-terraform";
          TimeoutStartSec = "10m";
          LoadCredential = credentialFiles;
        };

        path = with pkgs; [
          opentofu
          curl
          jq
          coreutils
        ];

        script = ''
          echo "Checking for ${serviceName} terraform configuration changes during deployment..."

          ${changeDetection.hashScript}
          CONFIG_CHANGED=$?

          if [ $CONFIG_CHANGED -eq 0 ]; then
            ${terraformExecutionScript}

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

      # Activation script for configuration change detection
      activationScript = mkIf autoApply changeDetection.activationScript;

      # Helper commands
      helperCommands = helperCommands;

      # Backend configuration generator (for manual use)
      backendConfigGenerator = generateBackendConfig backend instanceName;

      # Credential loader (for manual use)
      credentialLoader = credentialLoader;
    };

  # Simplified interface options for common use cases
  options = {
    backend = backendOptions;
  };

  # Backend type definitions for external use
  types = {
    backend = backendType;
    backendConfig = types.submodule {
      options = backendOptions;
    };
  };
}
