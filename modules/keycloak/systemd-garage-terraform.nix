# Systemd Service Orchestration for Garage and Keycloak-Terraform Integration
# This module provides complete systemd service definitions for:
# - Garage S3-compatible storage startup
# - Garage bucket and key initialization
# - Keycloak Terraform automation with Garage backend
{
  lib,
  pkgs,
  config,
  ...
}:

let
  inherit (lib) mkIf mkOption;
  inherit (lib.types) str bool;

  # Service configuration
  garageAdminPort = 3903;
  garageS3Port = 3900;
  terraformBucketName = "keycloak-terraform-state"; # Should be configurable per machine

  # Paths
  garageConfigDir = "/var/lib/garage";
  terraformWorkDir = "/var/lib/keycloak-terraform";
  credentialsDir = "/run/credentials";

  # Wait script for service readiness
  waitForService =
    service: port:
    pkgs.writeScript "wait-for-${service}" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      echo "Waiting for ${service} to be ready on port ${toString port}..."

      for i in {1..60}; do
        if ${pkgs.curl}/bin/curl -sf "http://localhost:${toString port}/health" >/dev/null 2>&1 || \
           ${pkgs.netcat}/bin/nc -z localhost ${toString port} >/dev/null 2>&1; then
          echo "${service} is ready!"
          exit 0
        fi
        echo "Attempt $i/60: ${service} not ready, waiting 5 seconds..."
        sleep 5
      done

      echo "ERROR: ${service} failed to become ready after 5 minutes"
      exit 1
    '';

  # Garage bucket initialization script
  garageBucketInit = pkgs.writeScript "garage-bucket-init" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "Initializing Garage bucket: ${terraformBucketName}"

    # Wait for Garage admin API
    ${waitForService "garage-admin" garageAdminPort}

    # Create bucket if it doesn't exist
    if ! ${pkgs.garage}/bin/garage -c ${garageConfigDir}/garage.toml \
         bucket info ${terraformBucketName} >/dev/null 2>&1; then
      echo "Creating bucket: ${terraformBucketName}"
      ${pkgs.garage}/bin/garage -c ${garageConfigDir}/garage.toml \
        bucket create ${terraformBucketName}
    else
      echo "Bucket ${terraformBucketName} already exists"
    fi

    echo "Bucket initialization complete"
  '';

  # Garage key initialization script
  garageKeyInit = pkgs.writeScript "garage-key-init" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "Initializing Garage keys for Terraform"

    # Key names
    KEY_NAME="terraform-backend"
    KEY_ID_FILE="${credentialsDir}/garage-terraform/access_key_id"
    SECRET_KEY_FILE="${credentialsDir}/garage-terraform/secret_access_key"

    # Create credentials directory
    mkdir -p "$(dirname "$KEY_ID_FILE")"

    # Check if key already exists
    if ${pkgs.garage}/bin/garage -c ${garageConfigDir}/garage.toml \
       key info "$KEY_NAME" >/dev/null 2>&1; then
      echo "Key $KEY_NAME already exists, retrieving credentials..."

      # Extract existing credentials
      KEY_INFO=$(${pkgs.garage}/bin/garage -c ${garageConfigDir}/garage.toml key info "$KEY_NAME")
      ACCESS_KEY=$(echo "$KEY_INFO" | grep "Access key ID:" | awk '{print $4}')
      SECRET_KEY=$(echo "$KEY_INFO" | grep "Secret access key:" | awk '{print $4}')
    else
      echo "Creating new key: $KEY_NAME"

      # Create new key
      KEY_OUTPUT=$(${pkgs.garage}/bin/garage -c ${garageConfigDir}/garage.toml key create "$KEY_NAME")
      ACCESS_KEY=$(echo "$KEY_OUTPUT" | grep "Access key ID:" | awk '{print $4}')
      SECRET_KEY=$(echo "$KEY_OUTPUT" | grep "Secret access key:" | awk '{print $4}')
    fi

    # Grant bucket permissions
    echo "Granting bucket permissions..."
    ${pkgs.garage}/bin/garage -c ${garageConfigDir}/garage.toml \
      bucket allow ${terraformBucketName} --read --write --key "$KEY_NAME"

    # Write credentials to files
    echo -n "$ACCESS_KEY" > "$KEY_ID_FILE"
    echo -n "$SECRET_KEY" > "$SECRET_KEY_FILE"

    # Set secure permissions
    chmod 600 "$KEY_ID_FILE" "$SECRET_KEY_FILE"

    echo "Garage key initialization complete"
    echo "Access Key ID: $ACCESS_KEY"
    echo "Credentials stored in: $(dirname "$KEY_ID_FILE")"
  '';

  # Keycloak health check script
  keycloakHealthCheck = pkgs.writeScript "keycloak-health-check" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "Checking Keycloak health..."

    for i in {1..120}; do
      # Check if Keycloak admin console is accessible
      if ${pkgs.curl}/bin/curl -sf "http://localhost:8080/auth/admin/" >/dev/null 2>&1; then
        echo "Keycloak admin console is accessible"

        # Check if we can authenticate with admin credentials
        ADMIN_PASSWORD=$(cat ${config.clan.core.vars.generators.keycloak-adeci.files.admin_password.path})

        # Try to get admin token
        if ${pkgs.curl}/bin/curl -sf \
           -d "client_id=admin-cli" \
           -d "username=admin" \
           -d "password=$ADMIN_PASSWORD" \
           -d "grant_type=password" \
           "http://localhost:8080/auth/realms/master/protocol/openid-connect/token" >/dev/null; then
          echo "Keycloak authentication successful"
          exit 0
        fi
      fi

      echo "Attempt $i/120: Keycloak not ready, waiting 5 seconds..."
      sleep 5
    done

    echo "ERROR: Keycloak failed to become ready after 10 minutes"
    exit 1
  '';

  # Terraform execution script
  terraformExecutor = pkgs.writeScript "keycloak-terraform-executor" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    cd ${terraformWorkDir}

    echo "Starting Keycloak Terraform automation..."

    # Load Garage credentials
    export AWS_ACCESS_KEY_ID=$(cat ${credentialsDir}/garage-terraform/access_key_id)
    export AWS_SECRET_ACCESS_KEY=$(cat ${credentialsDir}/garage-terraform/secret_access_key)
    export AWS_ENDPOINT_URL="http://localhost:${toString garageS3Port}"
    export AWS_REGION="garage"  # Garage doesn't use regions, but some tools expect this

    # Load Keycloak admin credentials
    export TF_VAR_keycloak_admin_password=$(cat ${config.clan.core.vars.generators.keycloak-adeci.files.admin_password.path})
    export TF_VAR_keycloak_url="http://localhost:8080/auth"

    # Ensure Keycloak is healthy
    ${keycloakHealthCheck}

    echo "Initializing Terraform..."
    ${pkgs.opentofu}/bin/tofu init \
      -backend-config="endpoint=http://localhost:${toString garageS3Port}" \
      -backend-config="bucket=${terraformBucketName}" \
      -backend-config="key=keycloak/terraform.tfstate" \
      -backend-config="region=garage" \
      -backend-config="skip_region_validation=true" \
      -backend-config="skip_credentials_validation=true" \
      -backend-config="skip_metadata_api_check=true" \
      -backend-config="force_path_style=true"

    echo "Planning Terraform changes..."
    ${pkgs.opentofu}/bin/tofu plan -out=tfplan

    echo "Applying Terraform configuration..."
    ${pkgs.opentofu}/bin/tofu apply -auto-approve tfplan

    echo "Keycloak Terraform automation completed successfully"
  '';

in
{
  options = {
    services.garage-terraform = {
      enable = mkOption {
        type = bool;
        default = false;
        description = "Enable Garage and Keycloak Terraform orchestration";
      };

      garageConfig = mkOption {
        type = str;
        default = "";
        description = "Garage configuration content";
      };
    };
  };

  config = mkIf config.services.garage-terraform.enable {

    # Garage service configuration
    systemd.services.garage = {
      description = "Garage S3-compatible distributed storage";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = "garage";
        RuntimeDirectory = "garage";

        # Environment variables
        Environment = [
          "GARAGE_CONFIG_FILE=${garageConfigDir}/garage.toml"
          "RUST_LOG=garage=info"
        ];

        ExecStartPre = pkgs.writeScript "garage-pre-start" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          # Create garage configuration
          cat > ${garageConfigDir}/garage.toml <<EOF
          ${config.services.garage-terraform.garageConfig}
          EOF

          # Set appropriate permissions
          chmod 600 ${garageConfigDir}/garage.toml
        '';

        ExecStart = "${pkgs.garage}/bin/garage -c ${garageConfigDir}/garage.toml server";

        Restart = "on-failure";
        RestartSec = "5s";

        # Security settings
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        RestrictRealtime = true;
        SystemCallFilter = [
          "@system-service"
          "~@privileged @resources"
        ];

        # Resource limits
        MemoryMax = "2G";
        TasksMax = 4096;
      };
    };

    # Garage bucket initialization (oneshot)
    systemd.services.garage-bucket-init = {
      description = "Initialize Garage bucket for Terraform state";
      after = [ "garage.service" ];
      requires = [ "garage.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        DynamicUser = true;

        ExecStart = garageBucketInit;

        # Retry on failure
        Restart = "on-failure";
        RestartSec = "10s";

        # Timeout settings
        TimeoutStartSec = "5min";

        # Security settings
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ garageConfigDir ];
      };
    };

    # Garage key initialization (oneshot)
    systemd.services.garage-key-init = {
      description = "Initialize Garage access keys for Terraform";
      after = [ "garage-bucket-init.service" ];
      requires = [ "garage-bucket-init.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        DynamicUser = true;

        # Create runtime credentials directory
        RuntimeDirectory = "credentials/garage-terraform";
        RuntimeDirectoryMode = "0700";

        ExecStart = garageKeyInit;

        # Retry on failure
        Restart = "on-failure";
        RestartSec = "10s";

        # Timeout settings
        TimeoutStartSec = "5min";

        # Security settings
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [
          garageConfigDir
          "/run/credentials/garage-terraform"
        ];
      };
    };

    # Keycloak Terraform automation (oneshot)
    systemd.services.keycloak-terraform = {
      description = "Keycloak Terraform Resource Management";
      after = [
        "keycloak.service"
        "garage-key-init.service"
      ];
      requires = [
        "keycloak.service"
        "garage-key-init.service"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        DynamicUser = true;

        # Working directory for Terraform
        StateDirectory = "keycloak-terraform";
        WorkingDirectory = terraformWorkDir;

        # Load Garage credentials from runtime directory
        LoadCredential = [
          "garage_access_key_id:/run/credentials/garage-terraform/access_key_id"
          "garage_secret_access_key:/run/credentials/garage-terraform/secret_access_key"
        ];

        ExecStart = terraformExecutor;

        # Retry on failure with backoff
        Restart = "on-failure";
        RestartSec = "30s";

        # Extended timeout for Terraform operations
        TimeoutStartSec = "20min";

        # Security settings
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        RestrictRealtime = true;
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];

        # Environment for Terraform
        Environment = [
          "TF_INPUT=false"
          "TF_IN_AUTOMATION=true"
          "TF_CLI_ARGS=-no-color"
        ];

        # Resource limits
        MemoryMax = "1G";
        TasksMax = 2048;
      };
    };

    # Service monitoring and restart orchestration
    systemd.services.garage-terraform-monitor = {
      description = "Monitor Garage-Terraform service health";
      after = [ "keycloak-terraform.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        ExecStart = pkgs.writeScript "garage-terraform-monitor" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          # Check service status
          if ! systemctl is-active --quiet garage.service; then
            echo "WARNING: Garage service is not active"
            exit 1
          fi

          if ! systemctl is-active --quiet keycloak.service; then
            echo "WARNING: Keycloak service is not active"
            exit 1
          fi

          # Check if oneshot services completed successfully
          for service in garage-bucket-init garage-key-init keycloak-terraform; do
            if ! systemctl show "$service.service" --property=ExecMainStatus --value | grep -q "^0$"; then
              echo "WARNING: $service failed to complete successfully"
              exit 1
            fi
          done

          echo "All Garage-Terraform services are healthy"
        '';

        # Run periodically
        # Note: This would typically be paired with a timer unit
      };
    };

    # Timer for periodic health checks (optional)
    systemd.timers.garage-terraform-monitor = {
      description = "Periodic health check for Garage-Terraform services";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = "1h";
        Persistent = true;
      };
    };

    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts = [
        garageAdminPort # Garage admin API
        garageS3Port # Garage S3 API
      ];
    };

    # Required packages
    environment.systemPackages = with pkgs; [
      garage
      opentofu
      curl
      netcat
    ];
  };
}
