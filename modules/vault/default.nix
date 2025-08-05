{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkIf
    mkMerge
    ;
  inherit (lib.types)
    bool
    str
    nullOr
    enum
    attrsOf
    anything
    ;
in
{
  _class = "clan.service";
  manifest.name = "vault";

  roles = {
    server = {
      interface = {
        # Freeform module - passes through to services.vault
        freeformType = attrsOf anything;

        options = {
          # Clan-specific convenience options
          domain = mkOption {
            type = nullOr str;
            default = null;
            description = "Domain name for the Vault service (e.g., example.com)";
          };

          subdomain = mkOption {
            type = str;
            default = "vault";
            description = "Subdomain for the Vault service";
          };

          enableACME = mkOption {
            type = bool;
            default = true;
            description = "Whether to enable automatic ACME/Let's Encrypt certificates";
          };

          storageType = mkOption {
            type = enum [
              "file"
              "raft"
              "inmem"
              "postgresql"
              "mysql"
              "consul"
            ];
            default = "file";
            description = "Storage backend type";
          };

          enableUI = mkOption {
            type = bool;
            default = true;
            description = "Enable the Vault web UI";
          };

          devMode = mkOption {
            type = bool;
            default = false;
            description = "Enable development mode (insecure, for testing only)";
          };

          tlsDisable = mkOption {
            type = bool;
            default = false;
            description = "Disable TLS (not recommended for production)";
          };

          # Auto-initialization settings
          autoInit = {
            enable = mkOption {
              type = bool;
              default = false;
              description = "Enable automatic initialization with pre-generated root token";
            };

            rootToken = mkOption {
              type = nullOr str;
              default = null;
              description = "Pre-generated root token for auto-initialization (will be stored in clan vars)";
            };
          };

          # HSM seal configuration
          hsmSeal = {
            enable = mkOption {
              type = bool;
              default = false;
              description = "Enable HSM-based auto-unseal (requires PKCS11 compatible HSM)";
            };

            lib = mkOption {
              type = str;
              default = "/usr/lib/opensc-pkcs11.so";
              description = "Path to PKCS11 library";
            };

            slot = mkOption {
              type = str;
              default = "0";
              description = "HSM slot number (as string)";
            };

            keyLabel = mkOption {
              type = str;
              default = "vault-unseal-key";
              description = "Label for the encryption key in the HSM";
            };

            mechanism = mkOption {
              type = str;
              default = "0x1087"; # CKM_AES_GCM
              description = "PKCS11 mechanism to use (hex string)";
            };

            generateKey = mkOption {
              type = bool;
              default = true;
              description = "Generate key on first initialization";
            };

            pinFile = mkOption {
              type = nullOr str;
              default = null;
              description = "Path to file containing HSM PIN (recommended over inline pin)";
            };
          };

          # Database configuration for postgresql/mysql backends
          database = {
            host = mkOption {
              type = nullOr str;
              default = null;
              description = "Database host for postgresql/mysql storage backends";
            };

            port = mkOption {
              type = nullOr str;
              default = null;
              description = "Database port";
            };

            name = mkOption {
              type = nullOr str;
              default = "vault";
              description = "Database name";
            };

            user = mkOption {
              type = nullOr str;
              default = "vault";
              description = "Database user";
            };
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              lib,
              pkgs,
              ...
            }:
            let
              settings = extendSettings { };

              # Extract clan-specific options
              inherit (settings)
                domain
                subdomain
                storageType
                enableUI
                devMode
                tlsDisable
                database
                autoInit
                hsmSeal
                ;

              # Full URL for the service
              vaultUrl = if domain != null then "https://${subdomain}.${domain}" else "http://localhost:8200";

              # Remove clan-specific options before passing to services.vault
              vaultConfig = builtins.removeAttrs settings [
                "domain"
                "subdomain"
                "enableACME"
                "storageType"
                "enableUI"
                "devMode"
                "tlsDisable"
                "database"
                "autoInit"
                "hsmSeal"
                # Don't remove storagePath - let NixOS module handle defaults
                "storageConfig" # Remove this as we handle it conditionally
              ];

              # Storage backend configuration
              storageConfig =
                if storageType == "file" then
                  # For file backend, NixOS module handles the path via storagePath option
                  # and expects storageConfig to be null/empty
                  ""
                else if storageType == "raft" then
                  ''
                    path = "/var/lib/vault/raft"
                    node_id = "${config.networking.hostName}"
                  ''
                else if storageType == "postgresql" then
                  ''
                    connection_url = "postgres://${database.user}:{{DB_PASSWORD}}@${database.host}:${database.port or "5432"}/${database.name}?sslmode=disable"
                    ha_enabled = "true"
                  ''
                else if storageType == "mysql" then
                  ''
                    connection_url = "${database.user}:{{DB_PASSWORD}}@tcp(${database.host}:${database.port or "3306"})/${database.name}"
                    ha_enabled = "true"
                  ''
                else if storageType == "consul" then
                  ''
                    address = "127.0.0.1:8500"
                    path = "vault/"
                  ''
                else
                  "";

              # Listener configuration
              listenerConfig =
                if !devMode && !tlsDisable && domain == null then
                  ''
                    tls_cert_file = "${config.clan.core.vars.generators.vault-tls.files."cert.pem".path}"
                    tls_key_file = "${config.clan.core.vars.generators.vault-tls.files."key.pem".path}"
                    tls_min_version = "tls12"
                  ''
                else if tlsDisable || devMode then
                  ''
                    tls_disable = 1
                  ''
                else
                  ''
                    tls_disable = 1
                  '';

            in
            {
              # Configure Vault service
              services.vault = lib.mkMerge [
                {
                  enable = true;
                  dev = devMode;
                  package = pkgs.vault-bin;

                  # Basic configuration
                  address = mkDefault "0.0.0.0:8200";

                  # Storage backend - in dev mode, storage is automatically inmem
                  storageBackend = if devMode then "inmem" else storageType;

                  # Listener configuration
                  listenerExtraConfig = listenerConfig;

                  # UI configuration
                  extraConfig = lib.mkMerge [
                    ''
                      ui = ${if enableUI then "true" else "false"}

                      api_addr = "${vaultUrl}"
                      cluster_addr = "https://${config.networking.hostName}:8201"

                      default_lease_ttl = "168h"
                      max_lease_ttl = "720h"
                    ''
                    # HSM seal configuration
                    (lib.mkIf (hsmSeal.enable && !devMode) ''
                      seal "pkcs11" {
                        lib = "${hsmSeal.lib}"
                        slot = "${hsmSeal.slot}"
                        ${lib.optionalString (hsmSeal.pinFile == null) ''pin = "$HSM_PIN"''}
                        key_label = "${hsmSeal.keyLabel}"
                        mechanism = "${hsmSeal.mechanism}"
                        generate_key = "${if hsmSeal.generateKey then "true" else "false"}"
                      }
                    '')
                  ];
                }
                # Only add storage config for non-dev mode and when it's not empty
                (lib.mkIf (!devMode && storageConfig != "") {
                  inherit storageConfig;
                })
                # For dev mode, explicitly set storagePath to null to avoid conflicts
                (lib.mkIf devMode {
                  storagePath = null;
                })
                vaultConfig
              ];

              # systemd service modifications
              systemd = {
                # Override systemd service for dev mode to add dev-listen-address
                services.vault = lib.mkMerge [
                  # Fix for dev mode listen address - NixOS vault module doesn't support -dev-listen-address
                  (lib.mkIf devMode {
                    serviceConfig = {
                      ExecStart = lib.mkForce "${pkgs.vault-bin}/bin/vault server -dev -dev-listen-address=${
                        settings.address or "0.0.0.0:8200"
                      } -dev-root-token-id=${settings.devRootTokenID or "dev-root-token"}";
                    };
                  })

                  # HSM PIN configuration
                  (lib.mkIf (hsmSeal.enable && !devMode) {
                    environment = lib.mkIf (hsmSeal.pinFile == null) {
                      HSM_PIN = "\${HSM_PIN}"; # Placeholder - should be set via EnvironmentFile
                    };

                    serviceConfig = lib.mkIf (hsmSeal.pinFile != null) {
                      EnvironmentFile = hsmSeal.pinFile;
                    };
                  })

                  # Secrets for database backends
                  (lib.mkIf (storageType == "postgresql" || storageType == "mysql") {
                    preStart = lib.mkAfter ''
                      # Replace database password placeholder in config
                      export DB_PASSWORD=$(cat ${config.clan.core.vars.generators.vault-db.files.password.path})

                      # Create a temporary config file with the password injected
                      mkdir -p /run/vault
                      cat > /run/vault/storage.hcl <<EOF
                      storage "${storageType}" {
                        ${builtins.replaceStrings [ "{{DB_PASSWORD}}" ] [ "$DB_PASSWORD" ] storageConfig}
                      }
                      EOF
                    '';

                    serviceConfig = {
                      ExecStart = lib.mkForce "${pkgs.vault-bin}/bin/vault server -config=/etc/vault.hcl -config=/run/vault/storage.hcl";
                    };
                  })
                ];

                # Simplified auto-initialization service
                services.vault-auto-init = lib.mkIf (!devMode && autoInit.enable) {
                  description = "Vault Auto-Initialization";
                  after = [ "vault.service" ];
                  requires = [ "vault.service" ];
                  wantedBy = [ "multi-user.target" ];

                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    User = "root";
                    WorkingDirectory = "/var/lib/vault";
                  };

                  path = with pkgs; [
                    curl
                    jq
                  ];

                  script = ''
                    set -euo pipefail

                    # Wait for Vault to be ready
                    echo "Waiting for Vault to start..."
                    for i in {1..30}; do
                      if ${pkgs.curl}/bin/curl -s http://127.0.0.1:8200/v1/sys/init >/dev/null 2>&1; then
                        break
                      fi
                      sleep 2
                    done

                    # Check if already initialized
                    INIT_STATUS=$(${pkgs.curl}/bin/curl -s http://127.0.0.1:8200/v1/sys/init | ${pkgs.jq}/bin/jq -r '.initialized' || echo "false")

                    if [ "$INIT_STATUS" = "true" ]; then
                      echo "Vault is already initialized"
                      
                      # Check if sealed
                      SEAL_STATUS=$(${pkgs.curl}/bin/curl -s http://127.0.0.1:8200/v1/sys/seal-status | ${pkgs.jq}/bin/jq -r '.')
                      SEALED=$(echo "$SEAL_STATUS" | ${pkgs.jq}/bin/jq -r '.sealed')
                      
                      if [ "$SEALED" = "true" ]; then
                        # Check for stored unseal keys - first in saved location, then in clan vars
                        if [ -f /var/lib/vault/init-keys/unseal_keys ]; then
                          echo "Vault is sealed. Attempting auto-unseal with saved keys..."
                          KEYS=$(cat /var/lib/vault/init-keys/unseal_keys | ${pkgs.jq}/bin/jq -r '.[]' 2>/dev/null)
                          if [ -n "$KEYS" ]; then
                            echo "$KEYS" | head -3 | while read -r key; do
                              if [ -n "$key" ]; then
                                echo "Unsealing with key..."
                                ${pkgs.curl}/bin/curl -s -X PUT http://127.0.0.1:8200/v1/sys/unseal \
                                  -H "Content-Type: application/json" \
                                  -d "{\"key\": \"$key\"}" || true
                              fi
                            done
                            
                            # Check if unsealed
                            FINAL_STATUS=$(${pkgs.curl}/bin/curl -s http://127.0.0.1:8200/v1/sys/seal-status | ${pkgs.jq}/bin/jq -r '.sealed')
                            if [ "$FINAL_STATUS" = "false" ]; then
                              echo "Vault successfully unsealed!"
                            else
                              echo "Vault is still sealed after auto-unseal attempt"
                            fi
                          fi
                        else
                          # Fallback to clan vars
                          KEYS_PATH="${config.clan.core.vars.generators.vault-init.files.unseal_keys.path}"
                          if [ -f "$KEYS_PATH" ] && [ -s "$KEYS_PATH" ] && [ "$(cat "$KEYS_PATH")" != "[]" ]; then
                            echo "Vault is sealed. Attempting auto-unseal with clan vars..."
                            KEYS=$(cat "$KEYS_PATH" | ${pkgs.jq}/bin/jq -r '.[]' 2>/dev/null || cat "$KEYS_PATH")
                            if [ -n "$KEYS" ]; then
                              echo "$KEYS" | head -3 | while read -r key; do
                                if [ -n "$key" ]; then
                                  echo "Unsealing with key..."
                                  ${pkgs.curl}/bin/curl -s -X PUT http://127.0.0.1:8200/v1/sys/unseal \
                                    -H "Content-Type: application/json" \
                                    -d "{\"key\": \"$key\"}" || true
                                fi
                              done
                              
                              # Check if unsealed
                              FINAL_STATUS=$(${pkgs.curl}/bin/curl -s http://127.0.0.1:8200/v1/sys/seal-status | ${pkgs.jq}/bin/jq -r '.sealed')
                              if [ "$FINAL_STATUS" = "false" ]; then
                                echo "Vault successfully unsealed!"
                              else
                                echo "Vault is still sealed after auto-unseal attempt"
                              fi
                            fi
                          else
                            echo "Vault is sealed - manual unseal required"
                            echo "No unseal keys found in /var/lib/vault/init-keys/ or clan vars"
                          fi
                        fi
                      else
                        echo "Vault is already unsealed"
                      fi
                    else
                      echo "Initializing Vault..."
                      
                      # Initialize Vault
                      INIT_OUTPUT=$(${pkgs.curl}/bin/curl -s -X PUT http://127.0.0.1:8200/v1/sys/init \
                        -H "Content-Type: application/json" \
                        -d '{"secret_shares": 5, "secret_threshold": 3}')
                      
                      # Check if initialization succeeded
                      if echo "$INIT_OUTPUT" | ${pkgs.jq}/bin/jq -e '.keys_base64' >/dev/null 2>&1; then
                        # Save to a writable location first
                        mkdir -p /var/lib/vault/init-keys
                        echo "$INIT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.keys_base64' > /var/lib/vault/init-keys/unseal_keys
                        echo "$INIT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.root_token' > /var/lib/vault/init-keys/root_token
                        chmod 600 /var/lib/vault/init-keys/*
                        
                        echo "========================================="
                        echo "VAULT INITIALIZED SUCCESSFULLY!"
                        echo "========================================="
                        echo ""
                        echo "IMPORTANT: Save these keys securely!"
                        echo ""
                        echo "Root Token:"
                        cat /var/lib/vault/init-keys/root_token
                        echo ""
                        echo "Unseal Keys:"
                        cat /var/lib/vault/init-keys/unseal_keys | ${pkgs.jq}/bin/jq -r '.[]'
                        echo ""
                        echo "========================================="
                        echo ""
                        echo "Keys saved to: /var/lib/vault/init-keys/"
                        echo ""
                        echo "To update clan vars with these keys, run:"
                        echo "  clan vars generate ${config.networking.hostName} --generator vault-keys"
                        echo ""
                        echo "Auto-unsealing Vault now..."
                        
                        # Auto-unseal with first 3 keys
                        echo "$INIT_OUTPUT" | ${pkgs.jq}/bin/jq -r '.keys_base64[0:3][]' | while read -r key; do
                          ${pkgs.curl}/bin/curl -s -X PUT http://127.0.0.1:8200/v1/sys/unseal \
                            -H "Content-Type: application/json" \
                            -d "{\"key\": \"$key\"}"
                        done
                        
                        echo "Vault is initialized and unsealed!"
                      else
                        echo "Failed to initialize Vault:"
                        echo "$INIT_OUTPUT"
                        exit 1
                      fi
                    fi
                  '';

                  environment = {
                    VAULT_ADDR = "http://127.0.0.1:8200";
                  };
                };

                # Create necessary directories
                tmpfiles.rules = [
                  "d /var/lib/vault 0700 vault vault -"
                ]
                ++ lib.optional (storageType == "raft") "d /var/lib/vault/raft 0700 vault vault -";
              };

              # Open firewall ports
              networking.firewall.allowedTCPPorts = [
                8200
                8201
              ];

              # Ensure vault user can read certificates and access HSM
              users.users.vault = {
                extraGroups = lib.mkMerge [
                  (lib.mkIf (!devMode && !tlsDisable) [ "nginx" ])
                  (lib.mkIf hsmSeal.enable [ "plugdev" ])
                ];
              };

              # Install HSM support packages
              environment.systemPackages = lib.mkIf hsmSeal.enable (
                with pkgs;
                [
                  opensc
                  pcsclite
                  pcsctools
                ]
              );

              # Enable PC/SC daemon for HSM access
              services.pcscd.enable = lib.mkIf hsmSeal.enable true;

              # Reverse proxy configuration (if using Traefik)
              # This would be handled by the tailscale-traefik service based on tags
            };
        };
    };
  };

  # Common configuration for all machines with vault
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        # Create vars generators for Vault secrets
        clan.core.vars.generators = {
          # Vault initialization tokens - placeholder generator
          # After Vault generates its keys, use vault-keys generator to retrieve them
          vault-init = {
            files.root_token = {
              secret = true;
              owner = "root";
              group = "root";
              mode = "0600";
            };
            files.unseal_keys = {
              secret = true;
              owner = "root";
              group = "root";
              mode = "0600";
            };
            runtimeInputs = [ ];
            script = ''
              # Create placeholder values - these are not used in production
              # After Vault initialization, regenerate with vault-keys generator
              echo "placeholder-root-token" > "$out/root_token"
              echo "[]" > "$out/unseal_keys"
            '';
          };

          # Generator to retrieve Vault-generated keys from the machine
          vault-keys = {
            files.root_token = {
              secret = true;
              owner = "root";
              group = "root";
              mode = "0600";
            };
            files.unseal_keys = {
              secret = true;
              owner = "root";
              group = "root";
              mode = "0600";
            };
            runtimeInputs = with pkgs; [ coreutils ];
            script = ''
              # This generator retrieves Vault-generated keys from local files
              # Run on the machine where Vault is initialized

              if [ -f /var/lib/vault/init-keys/root_token ]; then
                cat /var/lib/vault/init-keys/root_token > "$out/root_token"
              else
                echo "placeholder-root-token" > "$out/root_token"
              fi

              if [ -f /var/lib/vault/init-keys/unseal_keys ]; then
                cat /var/lib/vault/init-keys/unseal_keys > "$out/unseal_keys"
              else
                echo "[]" > "$out/unseal_keys"
              fi
            '';
          };

          # Database password generator (if using database backend)
          vault-db = {
            files.password = { };
            runtimeInputs = with pkgs; [ openssl ];
            script = ''
              openssl rand -base64 32 > "$out/password"
            '';
          };

          # Self-signed TLS certificates for development
          vault-tls = {
            files."cert.pem" = {
              owner = "vault";
              group = "vault";
              mode = "0644";
            };
            files."key.pem" = {
              owner = "vault";
              group = "vault";
              mode = "0600";
            };
            runtimeInputs = with pkgs; [ openssl ];
            script = ''
              # Generate self-signed certificate for local development
              openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
                -keyout "$out/key.pem" -out "$out/cert.pem" \
                -subj "/C=US/ST=State/L=City/O=Organization/CN=vault.local" \
                -addext "subjectAltName=DNS:vault.local,DNS:localhost,IP:127.0.0.1"
            '';
          };
        };
      };
  };
}
