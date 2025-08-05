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

                      # Create staging directories
                      mkdir -p /var/lib/acme-sync
                      chmod 755 /var/lib/acme-sync
                      chown root:acme-sync /var/lib/acme-sync

                      # Also create user-accessible directory for clan vars generator
                      # Use XDG_CACHE_HOME or fallback to ~/.cache
                      CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}"
                      USER_SYNC_DIR="$CACHE_DIR/clan-acme-sync"

                      # Try to create in cache dir for each likely user
                      for user_home in /home/*; do
                        if [ -d "$user_home" ]; then
                          user=$(basename "$user_home")
                          user_cache="$user_home/.cache/clan-acme-sync"
                          if mkdir -p "$user_cache" 2>/dev/null; then
                            chmod 755 "$user_cache"
                            echo "Created cache dir for user $user"
                          fi
                        fi
                      done

                      # Copy certificates to staging
                      ${lib.concatMapStrings (cert: ''
                        if [ -f "/var/lib/acme/${cert}/fullchain.pem" ] && [ -f "/var/lib/acme/${cert}/key.pem" ]; then
                          echo "Copying certificate for ${cert}..."
                          cp /var/lib/acme/${cert}/fullchain.pem /var/lib/acme-sync/${cert}.crt
                          cp /var/lib/acme/${cert}/key.pem /var/lib/acme-sync/${cert}.key
                          chmod 644 /var/lib/acme-sync/${cert}.crt
                          chmod 640 /var/lib/acme-sync/${cert}.key
                          chown root:acme-sync /var/lib/acme-sync/${cert}.*
                          
                          # Also copy to user cache directories
                          for user_home in /home/*; do
                            if [ -d "$user_home/.cache/clan-acme-sync" ]; then
                              user=$(basename "$user_home")
                              echo "Copying ${cert} certificates to $user's cache..."
                              cp /var/lib/acme/${cert}/fullchain.pem "$user_home/.cache/clan-acme-sync/${cert}.crt"
                              cp /var/lib/acme/${cert}/key.pem "$user_home/.cache/clan-acme-sync/${cert}.key"
                              # Make certs readable by user, keys only by owner
                              chown $user:$user "$user_home/.cache/clan-acme-sync/${cert}.*"
                              chmod 644 "$user_home/.cache/clan-acme-sync/${cert}.crt"
                              chmod 600 "$user_home/.cache/clan-acme-sync/${cert}.key"
                            fi
                          done
                        else
                          echo "Certificate files for ${cert} not found, skipping..."
                        fi
                      '') certsToManage}

                      # Trigger clan vars generation
                      if [ -n "$(ls -A /var/lib/acme-sync/)" ]; then
                        echo "Certificates synced to /var/lib/acme-sync"
                        echo "To store in clan vars, run:"
                        echo "  clan vars generate ${config.networking.hostName} --generator security-acme-certs-sync"
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
            # Define expected certificate files with proper ownership
            # These will be populated when certificates are generated
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
            # This is the placeholder generator - creates initial placeholder files
            # Use security-acme-certs-sync generator to populate with actual certificates

            echo "Creating placeholder certificate files..."
            echo "# Certificate placeholder - run security-acme-certs-sync generator after ACME generation" > "$out/onix.computer.crt"
            echo "# Key placeholder - run security-acme-certs-sync generator after ACME generation" > "$out/onix.computer.key"
            echo "# Certificate placeholder - run security-acme-certs-sync generator after ACME generation" > "$out/blr.dev.crt"
            echo "# Key placeholder - run security-acme-certs-sync generator after ACME generation" > "$out/blr.dev.key"
          '';
        };

        # Generator to retrieve actual certificates from the machine
        clan.core.vars.generators.security-acme-certs-sync = {
          files = {
            # Same files as above - must match exactly
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

            # Try multiple locations for certificates
            SYNC_DIRS=(
              "$HOME/.cache/clan-acme-sync"
              "/var/lib/acme-sync"
            )

            echo "Syncing ACME certificates..."

            # Copy certificates if they exist
            for cert in "onix.computer" "blr.dev"; do
              cert_copied=false
              key_copied=false
              
              for sync_dir in "''${SYNC_DIRS[@]}"; do
                cert_file="$sync_dir/$cert.crt"
                key_file="$sync_dir/$cert.key"
              
                # Certificate files
                if [ -f "$cert_file" ] && [ -r "$cert_file" ] && [ "$cert_copied" = false ]; then
                  echo "Copying $cert.crt from $sync_dir..." >&2
                  cp "$cert_file" "$out/$cert.crt" && cert_copied=true || {
                    echo "Failed to copy $cert_file" >&2
                  }
                fi
                
                # Key files
                if [ -f "$key_file" ] && [ -r "$key_file" ] && [ "$key_copied" = false ]; then
                  echo "Copying $cert.key from $sync_dir..." >&2
                  cp "$key_file" "$out/$cert.key" && key_copied=true || {
                    echo "Failed to copy $key_file" >&2
                  }
                fi
              done
              
              # Create placeholders if not copied
              if [ "$cert_copied" = false ]; then
                echo "Warning: $cert.crt not found in any sync directory" >&2
                echo "# Certificate not found - ensure ACME generation completed" > "$out/$cert.crt"
              fi
              
              if [ "$key_copied" = false ]; then
                echo "Warning: $cert.key not found in any sync directory" >&2
                echo "# Key not found - ensure ACME generation completed or check permissions" > "$out/$cert.key"
              fi
            done

            echo "Certificate sync complete"
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
