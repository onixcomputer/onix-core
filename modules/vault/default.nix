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
                "storagePath" # Remove this as we handle it conditionally
                "storageConfig" # Remove this as we handle it conditionally
              ];

              # Storage backend configuration
              storageConfig =
                if storageType == "file" then
                  ''
                    path = "/var/lib/vault"
                    node_id = "${config.networking.hostName}"
                  ''
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
                  extraConfig = ''
                    ui = ${if enableUI then "true" else "false"}

                    api_addr = "${vaultUrl}"
                    cluster_addr = "https://${config.networking.hostName}:8201"

                    default_lease_ttl = "168h"
                    max_lease_ttl = "720h"
                  '';
                }
                # Only add storage config for non-dev mode
                (lib.mkIf (!devMode) {
                  inherit storageConfig;
                })
                # Only add storagePath for file/raft backends when NOT in dev mode
                (lib.mkIf (!devMode && (storageType == "file" || storageType == "raft")) {
                  storagePath = mkDefault "/var/lib/vault";
                })
                vaultConfig
              ];

              # Override systemd service for dev mode to add dev-listen-address
              systemd.services.vault = lib.mkMerge [
                # Fix for dev mode listen address - NixOS vault module doesn't support -dev-listen-address
                (lib.mkIf devMode {
                  serviceConfig = {
                    ExecStart = lib.mkForce "${pkgs.vault-bin}/bin/vault server -dev -dev-listen-address=${
                      settings.address or "0.0.0.0:8200"
                    } -dev-root-token-id=${settings.devRootTokenID or "dev-root-token"} -config=/etc/vault.hcl";
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

              # Open firewall ports
              networking.firewall.allowedTCPPorts = [
                8200
                8201
              ];

              # Ensure vault user can read certificates
              users.users.vault = lib.mkIf (!devMode && !tlsDisable) {
                extraGroups = [ "nginx" ];
              };

              # Create necessary directories
              systemd.tmpfiles.rules = [
                "d /var/lib/vault 0700 vault vault -"
              ]
              ++ lib.optional (storageType == "raft") "d /var/lib/vault/raft 0700 vault vault -";

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
          vault-init = {
            files.root_token = { };
            files.unseal_keys = { };
            runtimeInputs = with pkgs; [ coreutils ];
            script = ''
              # These will be populated after vault initialization
              echo "PENDING_INITIALIZATION" > "$out/root_token"
              echo "PENDING_INITIALIZATION" > "$out/unseal_keys"
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
