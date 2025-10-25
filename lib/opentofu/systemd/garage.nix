# SystemD Garage S3 Backend Initialization
# Service for initializing Garage bucket and credentials for Terraform S3 backend
{ lib, pkgs }:

let
  pure = import ../lib-pure.nix { inherit lib; };
in

{
  # Generate Garage bucket init service for S3 backend
  mkTerranixGarageBackend =
    {
      serviceName,
      instanceName,
    }:
    let
      garageInitServiceName = pure.makeGarageInitServiceName instanceName;
      deploymentServiceName = pure.makeDeploymentServiceName serviceName instanceName;
      stateDir = "/var/lib/garage-terraform-${instanceName}";
    in
    {
      "${garageInitServiceName}" = {
        description = "Initialize Garage bucket for ${serviceName} Terraform";
        after = [ "garage.service" ];
        requires = [ "garage.service" ];
        before = [ "${deploymentServiceName}.service" ];
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
          WorkingDirectory = stateDir;
        };

        script = ''
          set -euo pipefail

          # Wait for Garage to be ready
          echo "Waiting for Garage API..."
          for i in {1..30}; do
            if curl -sf http://127.0.0.1:3903/health 2>/dev/null; then
              echo "✓ Garage API is ready"
              break
            fi
            [ "$i" -eq 30 ] && {
              echo "ERROR: Garage API failed to become ready after 60 seconds"
              exit 1
            }
            echo "Waiting for Garage API... (attempt $i/30)"
            sleep 2
          done

          GARAGE="${pkgs.garage}/bin/garage"

          # Create bucket if doesn't exist
          BUCKET_NAME="terraform-state"
          if ! "$GARAGE" bucket info "$BUCKET_NAME" 2>/dev/null; then
            echo "Creating $BUCKET_NAME bucket..."
            "$GARAGE" bucket create "$BUCKET_NAME"
            echo "✓ Created bucket: $BUCKET_NAME"
          else
            echo "✓ Bucket already exists: $BUCKET_NAME"
          fi

          # Create access key if doesn't exist
          KEY_NAME="${serviceName}-${instanceName}-tf"
          if ! "$GARAGE" key info "$KEY_NAME" 2>/dev/null; then
            echo "Creating access key for ${serviceName}-${instanceName}..."
            "$GARAGE" key create "$KEY_NAME"

            # Grant permissions
            "$GARAGE" bucket allow "$BUCKET_NAME" --read --write --owner --key "$KEY_NAME"
            echo "✓ Created access key: $KEY_NAME"
          else
            echo "✓ Access key already exists: $KEY_NAME"
          fi

          # Get credentials - parse text output
          echo "Retrieving credentials..."
          KEY_ID=$("$GARAGE" key info "$KEY_NAME" | grep -E '^Key ID:' | awk '{print $3}')
          SECRET=$("$GARAGE" key info "$KEY_NAME" --show-secret | grep -E '^Secret key:' | awk '{print $3}')

          if [ -z "$KEY_ID" ] || [ -z "$SECRET" ]; then
            echo "ERROR: Failed to retrieve credentials"
            echo "Key ID: '$KEY_ID'"
            echo "Secret: [hidden]"
            exit 1
          fi

          # Save credentials securely
          echo "$KEY_ID" > access_key_id
          echo "$SECRET" > secret_access_key
          chmod 600 access_key_id secret_access_key

          echo "✓ Garage bucket and credentials ready for ${serviceName}-${instanceName}"
          echo "  Bucket: $BUCKET_NAME"
          echo "  Key: $KEY_NAME"
          echo "  Credentials saved to: $PWD"
        '';
      };
    };

  # Generate credentials loading script for S3 backend
  mkS3CredentialsScript = instanceName: ''
    # Load S3/Garage credentials
    if [ ! -f "/var/lib/garage-terraform-${instanceName}/access_key_id" ] || [ ! -f "/var/lib/garage-terraform-${instanceName}/secret_access_key" ]; then
      echo "ERROR: S3 credentials not found for instance ${instanceName}"
      echo "Expected files:"
      echo "  /var/lib/garage-terraform-${instanceName}/access_key_id"
      echo "  /var/lib/garage-terraform-${instanceName}/secret_access_key"
      echo "Ensure garage-terraform-init-${instanceName}.service has run successfully"
      exit 1
    fi

    export AWS_ACCESS_KEY_ID=$(cat /var/lib/garage-terraform-${instanceName}/access_key_id)
    export AWS_SECRET_ACCESS_KEY=$(cat /var/lib/garage-terraform-${instanceName}/secret_access_key)
    echo "✓ Loaded S3 backend credentials for instance ${instanceName}"
  '';

  # Validate Garage service configuration
  validateGarageConfig =
    {
      serviceName,
      instanceName,
    }:
    let
      requiredFields = [
        "serviceName"
        "instanceName"
      ];
      providedFields = [
        serviceName
        instanceName
      ];
      missingFields = lib.zipListsWith (
        field: value: if value == null || value == "" then field else null
      ) requiredFields providedFields;
      actualMissing = builtins.filter (x: x != null) missingFields;
    in
    if actualMissing == [ ] then
      { inherit serviceName instanceName; }
    else
      throw "validateGarageConfig: Missing required fields: ${lib.concatStringsSep ", " actualMissing}";

  # Get Garage service dependencies
  getGarageDependencies = instanceName: [
    "garage.service"
    "garage-terraform-init-${instanceName}.service"
  ];

  # Check if Garage backend is configured for a service
  isGarageBackend = backendType: backendType == "s3";
}
