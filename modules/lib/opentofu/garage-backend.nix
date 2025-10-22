# Garage Backend Support for OpenTofu
# Extracted and generalized from the keycloak module
{ lib, pkgs, ... }:

let
  inherit (lib) mkOption types optionals;

  # Garage backend configuration options
  garageBackendOptions = {
    bucket = mkOption {
      type = types.str;
      default = "terraform-state";
      description = "Garage bucket name for terraform state";
    };

    endpoint = mkOption {
      type = types.str;
      default = "http://127.0.0.1:3900";
      description = "Garage S3 API endpoint";
    };

    region = mkOption {
      type = types.str;
      default = "garage";
      description = "Garage region identifier";
    };

    keyPrefix = mkOption {
      type = types.str;
      default = "";
      description = "Key prefix for organizing state files";
      example = "services/keycloak";
    };

    credentialsConfig = {
      adminTokenFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to Garage admin token file";
        example = "/run/credentials/garage/admin_token";
      };

      rpcSecretFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to Garage RPC secret file";
        example = "/run/credentials/garage/rpc_secret";
      };

      autoDetectClanVars = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically detect Garage credentials from clan vars";
      };
    };
  };

  # Generate Garage bucket initialization service
  generateGarageBucketService =
    {
      serviceName,
      instanceName,
      garageConfig,
      dependencies ? [ ],
    }:
    let
      bucketName = garageConfig.bucket;
      credentialsConfig = garageConfig.credentialsConfig;

      # Auto-detect clan vars credentials if enabled
      autoDetectedCredentials = lib.optionalAttrs credentialsConfig.autoDetectClanVars {
        adminTokenFile =
          if config.clan.core.vars.generators ? "garage" then
            config.clan.core.vars.generators.garage.files.admin_token.path
          else
            null;
        rpcSecretFile =
          if config.clan.core.vars.generators ? "garage-shared" then
            config.clan.core.vars.generators.garage-shared.files.rpc_secret.path
          else
            null;
      };

      # Merge credentials configuration
      finalCredentials = autoDetectedCredentials // credentialsConfig;

      # Service name
      serviceNameFull = "garage-terraform-init-${instanceName}";

    in
    {
      ${serviceNameFull} = {
        description = "Initialize Garage bucket for ${serviceName} OpenTofu";
        after = [ "garage.service" ] ++ dependencies;
        requires = [ "garage.service" ] ++ dependencies;
        before = [ "${serviceName}-terraform-deploy-${instanceName}.service" ];
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
            optionals (finalCredentials.adminTokenFile != null) [
              "admin_token:${finalCredentials.adminTokenFile}"
            ]
            ++ optionals (finalCredentials.rpcSecretFile != null) [
              "rpc_secret:${finalCredentials.rpcSecretFile}"
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

          # Load credentials from systemd credential files
          if [ -f "$CREDENTIALS_DIRECTORY/admin_token" ]; then
            export GARAGE_ADMIN_TOKEN=$(cat $CREDENTIALS_DIRECTORY/admin_token)
          fi

          if [ -f "$CREDENTIALS_DIRECTORY/rpc_secret" ]; then
            export GARAGE_RPC_SECRET=$(cat $CREDENTIALS_DIRECTORY/rpc_secret)
          fi

          GARAGE="${pkgs.garage}/bin/garage"
          BUCKET_NAME="${bucketName}"

          # Create bucket if doesn't exist
          if ! $GARAGE bucket info $BUCKET_NAME 2>/dev/null; then
            echo "Creating $BUCKET_NAME bucket..."
            $GARAGE bucket create $BUCKET_NAME
          fi

          # Create access key if doesn't exist
          KEY_NAME="${serviceName}-${instanceName}-tf"
          if ! $GARAGE key info $KEY_NAME 2>/dev/null; then
            echo "Creating access key for ${serviceName}-${instanceName}..."
            $GARAGE key create $KEY_NAME

            # Grant permissions
            $GARAGE bucket allow $BUCKET_NAME --read --write --owner --key $KEY_NAME
          fi

          # Get credentials - parse text output
          KEY_ID=$($GARAGE key info $KEY_NAME | grep -E '^Key ID:' | awk '{print $3}')
          SECRET=$($GARAGE key info $KEY_NAME --show-secret | grep -E '^Secret key:' | awk '{print $3}')

          # Save credentials for terraform to use
          echo "$KEY_ID" > access_key_id
          echo "$SECRET" > secret_access_key

          echo "Garage bucket '$BUCKET_NAME' and credentials ready for ${serviceName}-${instanceName}"
        '';
      };
    };

  # Generate Garage backend configuration
  generateGarageBackendConfig =
    {
      serviceName,
      instanceName,
      garageConfig,
    }:
    let
      bucketName = garageConfig.bucket;
      endpoint = garageConfig.endpoint;
      region = garageConfig.region;
      keyPath =
        if garageConfig.keyPrefix != "" then
          "${garageConfig.keyPrefix}/${instanceName}/terraform.tfstate"
        else
          "${serviceName}/${instanceName}/terraform.tfstate";
    in
    ''
      terraform {
        backend "s3" {
          endpoint = "${endpoint}"
          bucket = "${bucketName}"
          key = "${keyPath}"
          region = "${region}"

          skip_credentials_validation = true
          skip_metadata_api_check = true
          skip_region_validation = true
          force_path_style = true
        }
      }
    '';

  # Generate credential loading script for Garage
  generateGarageCredentialLoader = instanceName: ''
    # Load Garage credentials for S3-compatible backend
    GARAGE_CREDS_DIR="/var/lib/garage-terraform-${instanceName}"

    if [ -f "$GARAGE_CREDS_DIR/access_key_id" ] && [ -f "$GARAGE_CREDS_DIR/secret_access_key" ]; then
      export AWS_ACCESS_KEY_ID=$(cat $GARAGE_CREDS_DIR/access_key_id)
      export AWS_SECRET_ACCESS_KEY=$(cat $GARAGE_CREDS_DIR/secret_access_key)
      echo "Loaded Garage S3 credentials for ${instanceName}"
    else
      echo "ERROR: Garage credentials not found at $GARAGE_CREDS_DIR/"
      echo "Expected files: access_key_id, secret_access_key"
      exit 1
    fi
  '';

  # Enhanced deployment pattern with Garage support
  mkGarageBlockingDeployment =
    args@{
      serviceName,
      instanceName,
      garageConfig ? { },
      dependencies ? [ ],
      preTerraformScript ? "",
      enableDeployment ? true,
      ...
    }:
    let
      # Merge garage config with defaults
      finalGarageConfig = {
        bucket = "terraform-state";
        endpoint = "http://127.0.0.1:3900";
        region = "garage";
        keyPrefix = "";
        credentialsConfig = {
          autoDetectClanVars = true;
          adminTokenFile = null;
          rpcSecretFile = null;
        };
      }
      // garageConfig;

      # Import the existing deployment module and extend it
      deploymentModule = import ./deployment.nix { inherit lib pkgs; };

      # Generate Garage-specific components
      garageBucketServices = generateGarageBucketService {
        inherit serviceName instanceName dependencies;
        garageConfig = finalGarageConfig;
      };

      garageCredentialLoader = generateGarageCredentialLoader instanceName;

      # Extended S3 config for the base deployment
      extendedS3Config = {
        endpoint = finalGarageConfig.endpoint;
        bucket = finalGarageConfig.bucket;
        region = finalGarageConfig.region;
        credentialsPath = "/var/lib/garage-terraform-${instanceName}";
      };

      # Create the base deployment with S3 backend
      baseDeployment = deploymentModule.mkBlockingDeployment (
        args
        // {
          terraformBackend = "s3";
          s3Config = extendedS3Config;
          dependencies = dependencies ++ [ "garage-terraform-init-${instanceName}.service" ];
          preTerraformScript = preTerraformScript + "\n" + garageCredentialLoader;
        }
      );

    in
    lib.mkIf enableDeployment (
      lib.recursiveUpdate baseDeployment {
        # Add Garage bucket initialization service
        systemd.services = garageBucketServices;
      }
    );

in
{
  # Main functions
  inherit generateGarageBucketService generateGarageBackendConfig generateGarageCredentialLoader;
  inherit mkGarageBlockingDeployment;

  # Configuration options
  options = {
    garage = garageBackendOptions;
  };

  # Convenience functions
  garageHelpers = {
    # Create Garage backend config with clan vars auto-detection
    withClanVars =
      {
        bucket ? "terraform-state",
        keyPrefix ? "",
        endpoint ? "http://127.0.0.1:3900",
      }:
      {
        inherit bucket keyPrefix endpoint;
        region = "garage";
        credentialsConfig = {
          autoDetectClanVars = true;
        };
      };

    # Create Garage backend config with explicit credential files
    withCredentials =
      {
        bucket ? "terraform-state",
        keyPrefix ? "",
        endpoint ? "http://127.0.0.1:3900",
        adminTokenFile,
        rpcSecretFile ? null,
      }:
      {
        inherit bucket keyPrefix endpoint;
        region = "garage";
        credentialsConfig = {
          autoDetectClanVars = false;
          inherit adminTokenFile rpcSecretFile;
        };
      };
  };

  # Type definitions
  types = {
    garageBackend = types.submodule {
      options = garageBackendOptions;
    };
  };
}
