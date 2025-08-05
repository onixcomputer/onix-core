_: {
  instances = {
    # Vault with Pico HSM auto-unseal
    "vault-hsm" = {
      module.name = "vault";
      module.input = "self";
      roles.server = {
        tags."vault-hsm" = { };
        settings = {
          # Production configuration
          devMode = false;
          enableUI = true;

          # Storage backend
          storageType = "file";

          # Domain configuration for reverse proxy
          domain = "blr.dev";
          subdomain = "vault-hsm";
          enableACME = true;

          # TLS is handled by reverse proxy
          tlsDisable = true;

          # Bind to all interfaces for Traefik
          address = "0.0.0.0:8200";

          # Enable HSM auto-unseal
          hsmSeal = {
            enable = true;

            # OpenSC PKCS11 library path
            lib = "/run/current-system/sw/lib/opensc-pkcs11.so";

            # Slot 0 is usually the first HSM
            slot = "0";

            # Key label in the HSM
            keyLabel = "vault-unseal-key";

            # AES-GCM mechanism
            mechanism = "0x1087";

            # Generate key on first init (disable after)
            generateKey = true;

            # PIN file - create this file with HSM_PIN=yourpin
            pinFile = "/etc/vault/hsm-pin.env";
          };

          # Disable Shamir-based auto-init when using HSM
          autoInit = {
            enable = false;
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
            cluster_name = "vault-hsm"
          '';
        };
      };
    };

    # Example: Migrating from Shamir to HSM
    "vault-migrate-hsm" = {
      module.name = "vault";
      module.input = "self";
      roles.server = {
        tags."vault-migrate-hsm" = { };
        settings = {
          devMode = false;
          enableUI = true;
          storageType = "file";
          domain = "blr.dev";
          subdomain = "vault-migrate";
          enableACME = true;
          tlsDisable = true;
          address = "0.0.0.0:8200";

          # Enable HSM seal for migration
          hsmSeal = {
            enable = true;
            lib = "/run/current-system/sw/lib/opensc-pkcs11.so";
            slot = "0";
            keyLabel = "vault-unseal-key";
            mechanism = "0x1087";
            generateKey = true;
            pinFile = "/etc/vault/hsm-pin.env";
          };

          # Migration config - both seals configured
          extraConfig = ''
            # New HSM seal (configured above via hsmSeal)

            # Old Shamir seal marked as disabled
            seal "shamir" {
              disabled = true
            }

            ui = true
            disable_mlock = true
          '';
        };
      };
    };
  };
}
