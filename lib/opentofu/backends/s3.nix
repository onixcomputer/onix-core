# S3/Garage Backend Configuration Module
# Provides functions for S3-compatible object storage backend (specifically Garage)
{ lib, pkgs }:

let
  # Import pure functions from lib-pure.nix
  pureFuncs = import ../lib-pure.nix { inherit lib; };
in
rec {
  # Generate S3 backend configuration content
  inherit (pureFuncs) generateS3BackendConfig;

  # Create a complete S3/Garage backend configuration for a service
  mkS3Backend =
    { serviceName, instanceName }:
    {
      # Backend configuration file content
      backendConfig = pureFuncs.generateS3BackendConfig { inherit serviceName instanceName; };

      # Script to write backend configuration with credential loading
      backendScript = ''
        # Load S3/Garage credentials
        export AWS_ACCESS_KEY_ID=$(cat /var/lib/garage-terraform-${instanceName}/access_key_id)
        export AWS_SECRET_ACCESS_KEY=$(cat /var/lib/garage-terraform-${instanceName}/secret_access_key)
        echo "Loaded S3 backend credentials"

        cat > backend.tf <<'EOF'
        ${pureFuncs.generateS3BackendConfig { inherit serviceName instanceName; }}
        EOF
      '';

      # Backend type identifier
      backendType = "s3";

      # Additional services needed for S3 backend (Garage initialization)
      additionalServices = mkTerranixGarageBackend { inherit serviceName instanceName; };

      # State directory path
      stateDirectory = pureFuncs.makeStateDirectory serviceName instanceName;

      # Backend-specific environment variables
      environmentVariables = {
        AWS_ACCESS_KEY_ID = "/var/lib/garage-terraform-${instanceName}/access_key_id";
        AWS_SECRET_ACCESS_KEY = "/var/lib/garage-terraform-${instanceName}/secret_access_key";
      };

      # Pre-terraform setup script for credential verification
      preSetupScript = ''
        # Verify S3 credentials are available
        if [ ! -f "/var/lib/garage-terraform-${instanceName}/access_key_id" ] || [ ! -f "/var/lib/garage-terraform-${instanceName}/secret_access_key" ]; then
          echo "ERROR: S3 credentials not found. Ensure garage-terraform-init-${instanceName}.service has run successfully."
          exit 1
        fi
      '';
    };

  # Generate Garage bucket initialization service
  mkTerranixGarageBackend =
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

  # Validate S3 backend configuration
  validateS3Backend =
    config:
    let
      requiredFields = [
        "serviceName"
        "instanceName"
      ];
      missingFields = builtins.filter (field: !(config ? ${field})) requiredFields;
    in
    if missingFields != [ ] then
      throw "validateS3Backend: Missing required fields: ${lib.concatStringsSep ", " missingFields}"
    else
      config;

  # Helper to check if S3 backend is suitable for given configuration
  isS3BackendSuitable =
    {
      requiresSharedState ? false,
      ...
    }:
    requiresSharedState; # S3 backend is suitable when shared state is needed

  # S3-specific utilities
  mkS3CredentialPaths = instanceName: {
    accessKeyPath = "/var/lib/garage-terraform-${instanceName}/access_key_id";
    secretKeyPath = "/var/lib/garage-terraform-${instanceName}/secret_access_key";
  };

  # Generate S3 backend with custom endpoint
  mkCustomS3Backend =
    {
      serviceName,
      instanceName,
      endpoint ? "http://127.0.0.1:3900",
      bucket ? "terraform-state",
      region ? "garage",
    }:
    let
      customBackendConfig = ''
        terraform {
          backend "s3" {
            endpoint = "${endpoint}"
            bucket = "${bucket}"
            key = "${serviceName}/${instanceName}/terraform.tfstate"
            region = "${region}"
            skip_credentials_validation = true
            skip_metadata_api_check = true
            skip_region_validation = true
            force_path_style = true
          }
        }
      '';
    in
    {
      backendConfig = customBackendConfig;
      backendScript = ''
        # Load S3 credentials for custom endpoint
        export AWS_ACCESS_KEY_ID=$(cat /var/lib/garage-terraform-${instanceName}/access_key_id)
        export AWS_SECRET_ACCESS_KEY=$(cat /var/lib/garage-terraform-${instanceName}/secret_access_key)
        echo "Loaded S3 backend credentials for endpoint: ${endpoint}"

        cat > backend.tf <<'EOF'
        ${customBackendConfig}
        EOF
      '';
      backendType = "s3";
      additionalServices = mkTerranixGarageBackend { inherit serviceName instanceName; };
      stateDirectory = pureFuncs.makeStateDirectory serviceName instanceName;
      environmentVariables = {
        AWS_ACCESS_KEY_ID = "/var/lib/garage-terraform-${instanceName}/access_key_id";
        AWS_SECRET_ACCESS_KEY = "/var/lib/garage-terraform-${instanceName}/secret_access_key";
      };
      preSetupScript = ''
        # Verify S3 credentials are available
        if [ ! -f "/var/lib/garage-terraform-${instanceName}/access_key_id" ] || [ ! -f "/var/lib/garage-terraform-${instanceName}/secret_access_key" ]; then
          echo "ERROR: S3 credentials not found. Ensure garage-terraform-init-${instanceName}.service has run successfully."
          exit 1
        fi
      '';
    };
}
