{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkIf
    mkMerge
    types
    ;
in
{
  _class = "clan.service";
  manifest.name = "security-acme";

  roles = {
    # Certificate provider - generates certificates
    provider = {
      interface = {
        freeformType = types.attrsOf types.anything;

        options = {
          # Clan-specific options
          shareWildcard = mkOption {
            type = types.bool;
            default = false;
            description = "Generate and share a wildcard certificate via clan vars";
          };

          wildcardDomain = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "*.example.com";
            description = "Wildcard domain to generate (if shareWildcard is true)";
          };

          certificatesToShare = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [
              "example.com"
              "app.example.com"
            ];
            description = "List of certificate domains to share via clan vars";
          };

          dnsProvider = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "cloudflare";
            description = "DNS provider for DNS-01 challenge";
          };

          environmentFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Path to environment file with DNS provider credentials";
          };

          blockOnCertGeneration = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to block system activation waiting for certificates. If false, certificates are generated asynchronously after boot.";
          };

          email = mkOption {
            type = types.str;
            description = "Email address for Let's Encrypt account";
          };

          acceptTerms = mkOption {
            type = types.bool;
            default = false;
            description = "Accept Let's Encrypt terms of service";
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, ... }:
            let
              cfg = extendSettings { };

              # Extract clan-specific options
              clanOptions = [
                "shareWildcard"
                "wildcardDomain"
                "certificatesToShare"
                "dnsProvider"
                "environmentFile"
                "blockOnCertGeneration"
              ];

              # Remove clan options before passing to NixOS security.acme
              acmeConfig = builtins.removeAttrs cfg clanOptions;

              # Determine which certificates to manage
              certsToManage =
                (lib.optional (cfg.shareWildcard && cfg.wildcardDomain != null) cfg.wildcardDomain)
                ++ cfg.certificatesToShare;

              # Build certificate configurations
              certConfigs = lib.genAttrs certsToManage (
                domain:
                mkMerge [
                  {
                    # For wildcard certificates, add the wildcard as extraDomainNames
                    extraDomainNames =
                      if (cfg.shareWildcard && domain == cfg.wildcardDomain) then [ "*.${domain}" ] else [ ];
                    # DNS provider configuration per certificate
                    inherit (cfg) dnsProvider;
                    # Use credentialsFile instead of environmentFile for NixOS ACME
                    credentialsFile =
                      if cfg.environmentFile != null then
                        cfg.environmentFile
                      else
                        config.clan.core.vars.generators.security-acme-dns.files.cloudflare_env.path;
                    # Make certificates readable by acme group
                    group = "acme";
                    # Notify about successful generation
                    postRun = ''
                      echo "Certificate generated successfully for ${domain}"
                      echo ""
                      echo "To store in clan vars:"
                      echo ""
                      echo "Option 1 - Manual (run from controller):"
                      echo "  ssh ${config.networking.hostName} 'sudo cat /var/lib/acme/${domain}/fullchain.pem' | clan vars set ${config.networking.hostName} security-acme-certs/${domain}.crt"
                      echo "  ssh ${config.networking.hostName} 'sudo cat /var/lib/acme/${domain}/key.pem' | clan vars set ${config.networking.hostName} security-acme-certs/${domain}.key"
                      echo ""
                      echo "Option 2 - Systemd service (if configured):"
                      echo "  sudo systemctl start acme-cert-sync.service"
                    '';
                  }
                  # Allow per-cert overrides from freeform config
                  (cfg.certs.${domain} or { })
                ]
              );
            in
            {
              # Configure security.acme with both freeform and computed config
              security.acme = mkMerge [
                # Base configuration
                {
                  inherit (cfg) acceptTerms;
                  defaults = {
                    inherit (cfg) email;
                    group = mkDefault "acme";
                  };
                }
                # Apply freeform configuration
                acmeConfig
                # Add managed certificates
                {
                  certs = certConfigs;
                }
              ];

              # Service configurations
              systemd.services = mkMerge [
                # Control whether ACME services block system activation
                (mkIf (!cfg.blockOnCertGeneration) (
                  lib.genAttrs (map (cert: "acme-${cert}") certsToManage) (_: {
                    # Don't wait for certificate generation during activation
                    wantedBy = lib.mkForce [ ];
                    # Instead, use a timer to start it after boot
                    enable = true;
                  })
                ))

                # Service to trigger ACME after activation
                (mkIf (certsToManage != [ ] && !cfg.blockOnCertGeneration) {
                  acme-initial-certs = {
                    description = "Trigger initial ACME certificate generation";
                    wantedBy = [ "multi-user.target" ];
                    after = [
                      "network-online.target"
                      "tailscale.service"
                    ];
                    wants = [ "network-online.target" ];

                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                    };

                    script = ''
                      echo "Triggering ACME certificate generation for: ${lib.concatStringsSep ", " certsToManage}"

                      # Wait a bit for network to stabilize
                      sleep 10

                      ${lib.concatMapStrings (cert: ''
                        if [ ! -f "/var/lib/acme/${cert}/cert.pem" ] || [ -f "/var/lib/acme/${cert}/selfsigned" ]; then
                          echo "Starting acme-${cert}.service..."
                          systemctl start acme-${cert}.service || echo "Failed to start acme-${cert}.service"
                        else
                          echo "Certificate for ${cert} already exists, skipping..."
                        fi
                      '') certsToManage}
                    '';
                  };
                })

              ];

            };
        };
    };

    # Certificate controller - syncs certificates to clan vars
    controller = {
      interface = {
        options = {
          syncMachines = mkOption {
            type = types.attrsOf (
              types.submodule {
                options = {
                  certificates = mkOption {
                    type = types.listOf types.str;
                    description = "List of certificate domains to sync";
                    example = [
                      "onix.computer"
                      "blr.dev"
                    ];
                  };
                };
              }
            );
            default = { };
            description = "Machines to sync certificates from";
          };

          syncInterval = mkOption {
            type = types.str;
            default = "daily";
            description = "How often to sync certificates (systemd timer format)";
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              pkgs,
              lib,
              ...
            }:
            let
              cfg = extendSettings { };

              syncScript = pkgs.writeShellScript "acme-cert-sync" ''
                set -euo pipefail

                echo "[acme-cert-sync] Starting certificate synchronization"
                HOSTNAME=$(hostname)

                ${lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (machine: machineConfig: ''
                    echo "[acme-cert-sync] Syncing certificates from ${machine}..."
                    ${lib.concatMapStrings (cert: ''
                      echo "[acme-cert-sync] - Retrieving ${cert}..."

                      # Check if we're on the same machine
                      if [ "$HOSTNAME" = "${machine}" ]; then
                        # Local read (use sudo since we're not running as root)
                        if /run/wrappers/bin/sudo /run/current-system/sw/bin/test -f "/var/lib/acme/${cert}/fullchain.pem"; then
                          if /run/wrappers/bin/sudo /run/current-system/sw/bin/cat "/var/lib/acme/${cert}/fullchain.pem" | clan vars set ${machine} security-acme-certs/${cert}.crt; then
                            echo "[acme-cert-sync]   ✓ Certificate stored"
                          else
                            echo "[acme-cert-sync]   ✗ Failed to store certificate"
                          fi
                        else
                          echo "[acme-cert-sync]   ✗ Certificate file not found"
                        fi
                        
                        if /run/wrappers/bin/sudo /run/current-system/sw/bin/test -f "/var/lib/acme/${cert}/key.pem"; then
                          if /run/wrappers/bin/sudo /run/current-system/sw/bin/cat "/var/lib/acme/${cert}/key.pem" | clan vars set ${machine} security-acme-certs/${cert}.key; then
                            echo "[acme-cert-sync]   ✓ Key stored"
                          else
                            echo "[acme-cert-sync]   ✗ Failed to store key"
                          fi
                        else
                          echo "[acme-cert-sync]   ✗ Key file not found"
                        fi
                      else
                        # Remote SSH
                        if ssh ${machine} "sudo cat /var/lib/acme/${cert}/fullchain.pem 2>/dev/null" > /tmp/${cert}.crt; then
                          if [ -s /tmp/${cert}.crt ]; then
                            cat /tmp/${cert}.crt | clan vars set ${machine} security-acme-certs/${cert}.crt && \
                              echo "[acme-cert-sync]   ✓ Certificate stored"
                          fi
                        else
                          echo "[acme-cert-sync]   ✗ Failed to retrieve certificate"
                        fi
                        
                        if ssh ${machine} "sudo cat /var/lib/acme/${cert}/key.pem 2>/dev/null" > /tmp/${cert}.key; then
                          if [ -s /tmp/${cert}.key ]; then
                            cat /tmp/${cert}.key | clan vars set ${machine} security-acme-certs/${cert}.key && \
                              echo "[acme-cert-sync]   ✓ Key stored"
                          fi
                        else
                          echo "[acme-cert-sync]   ✗ Failed to retrieve key"
                        fi
                        
                        rm -f /tmp/${cert}.crt /tmp/${cert}.key
                      fi
                    '') machineConfig.certificates}
                  '') cfg.syncMachines
                )}

                echo "[acme-cert-sync] Synchronization complete"
              '';
            in
            mkIf (cfg.syncMachines != { }) {
              # Allow brittonr to read ACME certificates without password
              security.sudo.extraRules = [
                {
                  users = [ "brittonr" ];
                  commands = [
                    {
                      command = "/run/current-system/sw/bin/cat /var/lib/acme/*/fullchain.pem";
                      options = [ "NOPASSWD" ];
                    }
                    {
                      command = "/run/current-system/sw/bin/cat /var/lib/acme/*/key.pem";
                      options = [ "NOPASSWD" ];
                    }
                    {
                      command = "/run/current-system/sw/bin/test -f /var/lib/acme/*/fullchain.pem";
                      options = [ "NOPASSWD" ];
                    }
                    {
                      command = "/run/current-system/sw/bin/test -f /var/lib/acme/*/key.pem";
                      options = [ "NOPASSWD" ];
                    }
                  ];
                }
              ];

              # Sync service (system service)
              systemd.services.acme-cert-sync = {
                description = "Sync ACME certificates to clan vars";
                path = with pkgs; [
                  openssh
                  coreutils
                  hostname
                  git
                  nix
                  config.clan.core.clanPkgs.clan-cli
                  "/run/wrappers" # For sudo with setuid
                ];
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = syncScript;

                  # Run as brittonr user who has SOPS keys
                  User = "brittonr";
                  Group = "users";

                  # Environment for clan command
                  Environment = [
                    "HOME=/home/brittonr"
                    # Use the actual git repo path, not the nix store path
                    "CLAN_DIR=/home/brittonr/git/onix-core"
                  ];
                };
              };

              # Timer for automatic sync
              systemd.timers.acme-cert-sync = {
                description = "Timer for ACME certificate sync";
                wantedBy = [ "timers.target" ];

                timerConfig = {
                  OnCalendar = cfg.syncInterval;
                  Persistent = true;
                  RandomizedDelaySec = "1h";
                };
              };
            };
        };
    };

    # Certificate consumer - uses certificates from clan vars
    consumer = {
      interface = {
        options = {
          certificates = mkOption {
            type = types.attrsOf (
              types.submodule {
                options = {
                  domain = mkOption {
                    type = types.str;
                    description = "Domain name of the certificate to consume";
                    example = "*.example.com";
                  };

                  certPath = mkOption {
                    type = types.str;
                    readOnly = true;
                    description = "Path to the certificate file";
                  };

                  keyPath = mkOption {
                    type = types.str;
                    readOnly = true;
                    description = "Path to the private key file";
                  };

                  user = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "User that should own the certificate files";
                  };

                  group = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Group that should own the certificate files";
                  };

                  reloadServices = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "Services to reload when certificate is updated";
                  };
                };
              }
            );
            default = { };
            description = "Certificates to consume from clan vars";
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            _:
            let
              cfg = extendSettings { };
            in
            {
              # Create certificate directories and links
              systemd.services.setup-acme-consumer-certs = mkIf (cfg.certificates != { }) {
                description = "Setup ACME consumer certificates";
                wantedBy = [ "multi-user.target" ];
                before = cfg.certificates.${lib.head (lib.attrNames cfg.certificates)}.reloadServices or [ ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                };

                script = ''
                  mkdir -p /var/lib/acme-consumer

                  ${lib.concatStringsSep "\n" (
                    lib.mapAttrsToList (name: cert: ''
                      # Setup certificate: ${name}
                      # Look for certificate files in clan vars directory
                      VARS_DIR="/var/lib/clan-vars/security-acme-certs"
                      CERT_FILE="${cert.domain}.crt"
                      KEY_FILE="${cert.domain}.key"

                      if [ -f "$VARS_DIR/$CERT_FILE" ] && [ -f "$VARS_DIR/$KEY_FILE" ]; then
                        mkdir -p /var/lib/acme-consumer/${name}
                        cp "$VARS_DIR/$CERT_FILE" /var/lib/acme-consumer/${name}/fullchain.pem
                        cp "$VARS_DIR/$KEY_FILE" /var/lib/acme-consumer/${name}/key.pem
                        
                        ${lib.optionalString (cert.user != null) "chown ${cert.user} /var/lib/acme-consumer/${name}/*"}
                        ${lib.optionalString (cert.group != null) "chgrp ${cert.group} /var/lib/acme-consumer/${name}/*"}
                        chmod 640 /var/lib/acme-consumer/${name}/*
                        
                        echo "Certificate ${name} setup successfully"
                      else
                        echo "Warning: Certificate files for ${name} (${cert.domain}) not found in $VARS_DIR"
                        echo "Available files in $VARS_DIR:"
                        ls -la "$VARS_DIR" 2>/dev/null || echo "Directory not found"
                      fi
                    '') cfg.certificates
                  )}

                  # Reload services if needed
                  ${lib.concatMapStrings (
                    cert:
                    lib.concatMapStrings (service: ''
                      systemctl reload ${service} || true
                    '') cert.reloadServices
                  ) (lib.attrValues cfg.certificates)}
                '';
              };

              # Add certificate paths to the configuration
              services.security-acme.consumer.certificates = lib.mapAttrs (
                name: cert:
                cert
                // {
                  certPath = "/var/lib/acme-consumer/${name}/fullchain.pem";
                  keyPath = "/var/lib/acme-consumer/${name}/key.pem";
                }
              ) cfg.certificates;
            };
        };
    };
  };

  # Common configuration for all machines
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        # Create vars generator for ACME certificates
        clan.core.vars.generators.security-acme-certs = {
          files = {
            # Define expected certificate files with proper ownership
            "onix.computer.crt" = {
              owner = "root";
              group = "root";
              mode = "0644";
            };
            "onix.computer.key" = {
              secret = true;
              owner = "root";
              group = "root";
              mode = "0600";
            };
            "blr.dev.crt" = {
              owner = "root";
              group = "root";
              mode = "0644";
            };
            "blr.dev.key" = {
              secret = true;
              owner = "root";
              group = "root";
              mode = "0600";
            };
          };

          runtimeInputs = with pkgs; [
            coreutils
          ];

          prompts = { };

          script = ''
            # This generator retrieves ACME certificates from local files
            # Run on the machine where certificates are generated
            # Following the same pattern as vault-keys generator

            for cert in "onix.computer" "blr.dev"; do
              if [ -f "/var/lib/acme/$cert/fullchain.pem" ]; then
                cat "/var/lib/acme/$cert/fullchain.pem" > "$out/$cert.crt"
              else
                echo "# Certificate placeholder - waiting for ACME generation" > "$out/$cert.crt"
              fi
              
              if [ -f "/var/lib/acme/$cert/key.pem" ]; then
                cat "/var/lib/acme/$cert/key.pem" > "$out/$cert.key"
              else
                echo "# Key placeholder - waiting for ACME generation" > "$out/$cert.key"
              fi
            done
          '';
        };

        # Create vars generator for DNS provider credentials
        clan.core.vars.generators.security-acme-dns = {
          files = {
            cloudflare_env = {
              mode = "0600";
            };
            # Add more providers as needed
          };

          runtimeInputs = [ pkgs.coreutils ];

          prompts = {
            cloudflare_email = {
              description = "Cloudflare account email";
              type = "line";
              persist = true;
            };
            cloudflare_api_token = {
              description = "Cloudflare API token with DNS edit permissions";
              type = "hidden";
              persist = true;
            };
          };

          script = ''
            # Generate Cloudflare environment file for Lego
            # Using CF_DNS_API_TOKEN as per https://go-acme.github.io/lego/dns/cloudflare/
            echo "Generating Cloudflare environment file..."
            TOKEN=$(cat "$prompts"/cloudflare_api_token)
            cat > "$out"/cloudflare_env <<EOF
            CF_DNS_API_TOKEN=$TOKEN
            CLOUDFLARE_DNS_API_TOKEN=$TOKEN
            CLOUDFLARE_PROPAGATION_TIMEOUT=600
            CLOUDFLARE_POLLING_INTERVAL=10
            CLOUDFLARE_TTL=120
            EOF
            echo "Environment file generated with $(wc -l < "$out"/cloudflare_env) lines"
          '';
        };
      };
  };
}
