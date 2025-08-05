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

          renewalCheckInterval = mkOption {
            type = types.str;
            default = "daily";
            description = "How often to check for certificate renewal and sync to clan vars";
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
                "renewalCheckInterval"
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
                    # Ensure certificates are readable by sync service
                    group = "acme-sync";
                    # Trigger sync after successful certificate generation
                    postRun = ''
                      echo "Certificate generated successfully for ${domain}, triggering sync..."
                      ls -la /var/lib/acme/${domain}/ || echo "Directory not found"
                      # Don't use systemctl start as it creates a dependency deadlock
                      # Instead, just notify that sync is needed
                      echo "Certificate ready for syncing to clan vars"
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

              # Create group for certificate syncing
              users.groups.acme-sync = { };

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

                # Sync service
                (mkIf (certsToManage != [ ]) {
                  sync-acme-certs = {
                    description = "Sync ACME certificates to clan vars";
                    after = map (cert: "acme-${cert}.service") certsToManage;

                    serviceConfig = {
                      Type = "oneshot";
                      User = "root";
                      Group = "acme-sync";
                    };

                    script = ''
                      echo "Syncing ACME certificates to clan vars..."

                      # Create staging directory  
                      mkdir -p /var/lib/acme-sync
                      chmod 755 /var/lib/acme-sync
                      chown root:acme-sync /var/lib/acme-sync

                      # Copy certificates to staging
                      ${lib.concatMapStrings (cert: ''
                        if [ -f "/var/lib/acme/${cert}/fullchain.pem" ] && [ -f "/var/lib/acme/${cert}/key.pem" ]; then
                          echo "Copying certificate for ${cert}..."
                          cp /var/lib/acme/${cert}/fullchain.pem /var/lib/acme-sync/${cert}.crt
                          cp /var/lib/acme/${cert}/key.pem /var/lib/acme-sync/${cert}.key
                          chmod 644 /var/lib/acme-sync/${cert}.crt
                          chmod 640 /var/lib/acme-sync/${cert}.key
                          chown root:acme-sync /var/lib/acme-sync/${cert}.*
                        else
                          echo "Certificate files for ${cert} not found, skipping..."
                        fi
                      '') certsToManage}

                      # Trigger clan vars generation
                      if [ -n "$(ls -A /var/lib/acme-sync/)" ]; then
                        echo "Certificates synced to /var/lib/acme-sync"
                        # Note: Automatic clan vars generation would require clan-cli in PATH
                        # and proper permissions. For now, manual generation is needed.
                        echo "Run 'sudo clan vars generate britton-fw --generator security-acme-certs' to store in clan vars"
                      fi
                    '';
                  };
                })

                # No need for explicit ordering - path watcher handles it
                { }
              ];

              # Timer to periodically sync certificates
              systemd.timers.sync-acme-certs = mkIf (certsToManage != [ ]) {
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnCalendar = cfg.renewalCheckInterval;
                  Persistent = true;
                };
              };

              # Path unit to watch for certificate changes
              systemd.paths.sync-acme-certs = mkIf (certsToManage != [ ]) {
                wantedBy = [ "paths.target" ];
                pathConfig = {
                  PathChanged = map (cert: "/var/lib/acme/${cert}/fullchain.pem") certsToManage;
                  Unit = "sync-acme-certs.service";
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
            # Define expected certificate files as placeholders
            # These will be populated when certificates are generated
            "onix.computer.crt" = {
              mode = "0640";
            };
            "onix.computer.key" = {
              mode = "0600";
            };
            "blr.dev.crt" = {
              mode = "0640";
            };
            "blr.dev.key" = {
              mode = "0600";
            };
          };

          runtimeInputs = with pkgs; [
            coreutils
            findutils
          ];

          prompts = { };

          script = ''
            # Check if we can read from the sync directory
            if [ -r /var/lib/acme-sync ] && [ -d /var/lib/acme-sync ]; then
              # Copy all certificates from staging to output
              if [ -n "$(ls -A /var/lib/acme-sync/ 2>/dev/null)" ]; then
                echo "Found certificates in /var/lib/acme-sync:"
                ls -la /var/lib/acme-sync/ 2>/dev/null || true
                
                copied=0
                for file in /var/lib/acme-sync/*; do
                  if [ -f "$file" ] && [ -r "$file" ]; then
                    basename=$(basename "$file")
                    echo "Copying $basename to clan vars..."
                    cp "$file" "$out/$basename"
                    copied=$((copied + 1))
                  elif [ -f "$file" ]; then
                    basename=$(basename "$file")
                    echo "Warning: Cannot read $file (permission denied)"
                    echo "Note: Run 'sudo clan vars generate britton-fw --generator security-acme-certs' to copy all certificates"
                  fi
                done
                
                if [ $copied -gt 0 ]; then
                  echo "Successfully copied $copied certificate file(s)"
                fi
              else
                echo "No certificates found in /var/lib/acme-sync"
              fi
            else
              echo "Cannot access /var/lib/acme-sync directory (expected on first run)"
            fi

            # Create placeholders for any missing certificate files
            for cert_file in "onix.computer.crt" "onix.computer.key" "blr.dev.crt" "blr.dev.key"; do
              if [ ! -f "$out/$cert_file" ]; then
                echo "Creating placeholder for $cert_file"
                echo "# Certificate placeholder - will be populated after ACME generation" > "$out/$cert_file"
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
