_: {
  instances = {
    # Development Vault instance (in-memory, unsealed)
    "vault-dev" = {
      module.name = "vault";
      module.input = "self";
      roles.server = {
        tags."vault-dev" = { };
        settings = {
          # Development mode - insecure, for testing only
          devMode = true;
          enableUI = true;

          # Override default dev settings if needed
          devRootTokenID = "dev-root-token";

          # Domain configuration
          domain = "blr.dev";
          subdomain = "vault1";

          # Listen on all interfaces for Traefik access
          address = "0.0.0.0:8200";

          # Dev mode config
          extraConfig = ''
            ui = true
            disable_mlock = true
          '';
        };
      };
    };

    # Production Vault instance with file storage
    "vault-prod" = {
      module.name = "vault";
      module.input = "self";
      roles.server = {
        tags."vault-production" = { };
        settings = {
          # Production configuration
          devMode = false;
          enableUI = true;

          # Storage backend
          storageType = "file";
          # storagePath is handled by the module based on storageType

          # Domain configuration for reverse proxy
          domain = "blr.dev";
          subdomain = "vault1";
          enableACME = true;

          # TLS is handled by reverse proxy
          tlsDisable = true;

          # Bind to all interfaces for Traefik
          address = "0.0.0.0:8200";

          # Enable auto-initialization
          autoInit = {
            enable = true;
          };

          # HSM configuration (disabled for now - enable when ready)
          hsmSeal = {
            enable = false; # Enable when HSM is connected to britton-fw
            lib = "/run/current-system/sw/lib/opensc-pkcs11.so";
            slot = "0";
            keyLabel = "vault-unseal-key";
            mechanism = "0x1087";
            generateKey = true;
            pinFile = "/etc/vault/hsm-pin.env";
          };

          # Additional Vault configuration
          extraConfig = ''
            telemetry {
              prometheus_retention_time = "30s"
              disable_hostname = true
            }

            # Disable mlock for compatibility
            disable_mlock = true

            # Set cluster name
            cluster_name = "vault-prod"
          '';
        };
      };
    };

    # High-availability Vault with Raft storage
    "vault-ha" = {
      module.name = "vault";
      module.input = "self";
      roles.server = {
        tags."vault-ha" = { };
        settings = {
          devMode = false;
          enableUI = true;

          # Raft integrated storage for HA
          storageType = "raft";

          # Domain configuration
          domain = "example.com";
          subdomain = "vault";
          enableACME = true;
          tlsDisable = true;

          # Bind to all interfaces for cluster communication
          address = "0.0.0.0:8200";

          # Raft configuration via extraSettingsPaths
          extraSettingsPaths = [ "/etc/vault/raft-config.hcl" ];

          extraConfig = ''
            cluster_name = "vault-cluster"

            seal "awskms" {
              region     = "us-east-1"
              kms_key_id = "REPLACE_WITH_KMS_KEY_ID"
            }
          '';
        };
      };
    };

    # Vault with PostgreSQL backend
    "vault-postgres" = {
      module.name = "vault";
      module.input = "self";
      roles.server = {
        tags."vault-postgres" = { };
        settings = {
          devMode = false;
          enableUI = true;

          # PostgreSQL storage backend
          storageType = "postgresql";

          # Database configuration
          database = {
            host = "postgres.internal";
            port = "5432";
            name = "vault";
            user = "vault";
          };

          # Domain configuration
          domain = "example.com";
          subdomain = "vault";
          enableACME = true;
          tlsDisable = true;

          address = "127.0.0.1:8200";

          # Performance tuning
          extraConfig = ''
            default_lease_ttl = "24h"
            max_lease_ttl = "168h"

            plugin_directory = "/var/lib/vault/plugins"
          '';
        };
      };
    };
  };
}
