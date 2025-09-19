{ lib, ... }:
{
  _class = "clan.service";
  manifest.name = "garage";
  manifest.description = "S3-compatible object store for Terraform state";

  roles = {
    server = {
      interface = {
        # Freeform module - allow any garage settings
        freeformType = lib.types.attrsOf lib.types.anything;
      };

      perInstance =
        { instanceName, extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              pkgs,
              lib,
              ...
            }:
            let
              settings = extendSettings { };
            in
            {
              # Use the built-in NixOS Garage service
              services.garage = {
                enable = lib.mkDefault true;
                package = lib.mkDefault pkgs.garage;

                settings = lib.mkMerge [
                  {
                    # Default configuration for single-node Terraform state storage
                    metadata_dir = lib.mkDefault "/var/lib/garage/meta";
                    data_dir = lib.mkDefault "/var/lib/garage/data";

                    replication_mode = lib.mkDefault "1";

                    compression_level = lib.mkDefault 1;

                    db_engine = lib.mkDefault "lmdb";

                    rpc_bind_addr = lib.mkDefault "[::]:3901";
                    rpc_public_addr = lib.mkDefault "127.0.0.1:3901";

                    s3_api = {
                      s3_region = lib.mkDefault "garage";
                      api_bind_addr = lib.mkDefault "[::]:3900";
                      root_domain = lib.mkDefault ".s3.garage.localhost";
                    };

                    k2v_api = {
                      api_bind_addr = lib.mkDefault "[::]:3904";
                    };

                    admin = {
                      api_bind_addr = lib.mkDefault "[::]:3903";
                    };

                    web = {
                      bind_addr = lib.mkDefault "[::]:3902";
                      root_domain = lib.mkDefault ".web.garage.localhost";
                    };
                  }
                  # Allow overrides from settings
                  settings
                ];
              };

              # Configure systemd service to load credentials
              systemd.services.garage = {
                serviceConfig = {
                  LoadCredential = [
                    "rpc_secret:${
                      config.clan.core.vars.generators."garage-shared-${instanceName}".files.rpc_secret.path
                    }"
                    "admin_token:${config.clan.core.vars.generators."garage-${instanceName}".files.admin_token.path}"
                  ];
                  Environment = [
                    "GARAGE_ALLOW_WORLD_READABLE_SECRETS=true"
                    "GARAGE_RPC_SECRET_FILE=%d/rpc_secret"
                    "GARAGE_ADMIN_TOKEN_FILE=%d/admin_token"
                  ];
                };
              };

              # Separate oneshot service for Garage initialization
              systemd.services."garage-init-${instanceName}" = {
                description = "Initialize Garage cluster for ${instanceName}";
                after = [ "garage.service" ];
                requires = [ "garage.service" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;

                  # Load both RPC secret and admin token
                  LoadCredential = [
                    "rpc_secret:${
                      config.clan.core.vars.generators."garage-shared-${instanceName}".files.rpc_secret.path
                    }"
                    "admin_token:${config.clan.core.vars.generators."garage-${instanceName}".files.admin_token.path}"
                  ];
                };

                script = ''
                  set -euo pipefail

                  # Export credentials for garage CLI
                  # Using direct environment variables (not _FILE variants)
                  export GARAGE_RPC_SECRET=$(cat $CREDENTIALS_DIRECTORY/rpc_secret)
                  export GARAGE_ADMIN_TOKEN=$(cat $CREDENTIALS_DIRECTORY/admin_token)

                  echo "Waiting for Garage to be ready..."
                  for i in {1..30}; do
                    if ${pkgs.garage}/bin/garage status 2>/dev/null | grep -q "ID"; then
                      echo "Garage is ready!"
                      break
                    fi
                    echo "Waiting... ($i/30)"
                    sleep 2
                  done

                  # Check if already configured by looking for existing layout with assigned nodes
                  if ${pkgs.garage}/bin/garage layout show 2>/dev/null | grep -q "CAPACITY"; then
                    echo "Garage cluster already configured, checking buckets..."
                  else
                    # Get node ID (without the @address part)
                    NODE_ID_FULL=$(${pkgs.garage}/bin/garage node id -q)
                    NODE_ID=$(echo "$NODE_ID_FULL" | cut -d'@' -f1)
                    echo "Configuring Garage layout for node $NODE_ID..."

                    # Assign the node to the cluster
                    ${pkgs.garage}/bin/garage layout assign $NODE_ID -z dc1 -c 1000 -t node1

                    # Get current layout version and increment it
                    CURRENT_VERSION=$(${pkgs.garage}/bin/garage layout show 2>/dev/null | grep -oP 'version:\s+\K\d+' || echo "0")
                    NEXT_VERSION=$((CURRENT_VERSION + 1))

                    echo "Applying layout version $NEXT_VERSION..."
                    ${pkgs.garage}/bin/garage layout apply --version $NEXT_VERSION
                    echo "Layout configured!"
                    sleep 5
                  fi

                  # Create Terraform state buckets if they don't exist
                  for bucket in terraform-state-dev terraform-state-staging terraform-state-prod; do
                    if ${pkgs.garage}/bin/garage bucket list 2>/dev/null | grep -qE "^$bucket"; then
                      echo "Bucket $bucket already exists"
                    else
                      echo "Creating bucket: $bucket"
                      ${pkgs.garage}/bin/garage bucket create $bucket || {
                        echo "Note: Bucket $bucket may already exist, continuing..."
                      }
                    fi
                  done

                  # Create terraform access key if it doesn't exist
                  if ${pkgs.garage}/bin/garage key list 2>/dev/null | grep -qE "^terraform\s"; then
                    echo "Terraform key already exists"
                  else
                    echo "Creating terraform access key..."
                    ${pkgs.garage}/bin/garage key create terraform || {
                      echo "Note: Key terraform may already exist, continuing..."
                    }

                    # Grant permissions to all buckets
                    for bucket in terraform-state-dev terraform-state-staging terraform-state-prod; do
                      echo "Granting permissions to $bucket..."
                      ${pkgs.garage}/bin/garage bucket allow --read --write --owner $bucket --key terraform || {
                        echo "Note: Permissions may already be set, continuing..."
                      }
                    done
                  fi

                  # Always show key info at the end
                  echo ""
                  echo "=== Terraform Access Key Info ==="
                  ${pkgs.garage}/bin/garage key info terraform || true
                  echo "================================="
                  echo ""
                  echo "Use these credentials to update clan vars:"
                  echo "  clan vars set britton-fw garage-terraform-${instanceName}/s3_access_key <KEY_ID>"
                  echo "  clan vars set britton-fw garage-terraform-${instanceName}/s3_secret_key <SECRET_KEY>"
                '';
              };

              # Clan vars generators for secrets
              clan.core.vars.generators."garage-${instanceName}" = {
                files.admin_token = {
                  secret = true;
                };
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.openssl
                ];
                script = ''
                  openssl rand -hex 32 > "$out"/admin_token
                '';
              };

              clan.core.vars.generators."garage-shared-${instanceName}" = {
                share = true;
                files.rpc_secret = {
                  secret = true;
                };
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.openssl
                ];
                script = ''
                  openssl rand -hex 32 > "$out"/rpc_secret
                '';
              };

              # Clan vars generator for Terraform S3 credentials
              clan.core.vars.generators."garage-terraform-${instanceName}" = {
                files.s3_access_key = {
                  secret = false;
                };
                files.s3_secret_key = {
                  secret = true;
                };
                prompts = {
                  s3_access_key = {
                    description = "Garage S3 Access Key for Terraform (from 'garage key info terraform')";
                  };
                  s3_secret_key = {
                    description = "Garage S3 Secret Key for Terraform (from 'garage key info terraform')";
                    type = "hidden";
                  };
                };
                script = ''
                  echo "$prompt_value_s3_access_key" > "$out"/s3_access_key
                  echo "$prompt_value_s3_secret_key" > "$out"/s3_secret_key
                '';
              };

              # Track Garage state
              clan.core.state.garage.folders = [
                config.services.garage.settings.metadata_dir
                config.services.garage.settings.data_dir
              ];

              # Open firewall ports
              networking.firewall.allowedTCPPorts = [
                3900 # S3 API
                3901 # RPC
                3902 # Web
                3903 # Admin API
                3904 # K2V API
              ];
            };
        };
    };
  };
}
