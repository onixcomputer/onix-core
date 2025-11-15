{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkIf
    mkForce
    concatMapStringsSep
    ;
  inherit (lib.types)
    nullOr
    attrsOf
    anything
    str
    bool
    enum
    listOf
    ;

  # Common function to build seeding policy settings
  mkSeedingPolicy =
    policy:
    if policy == "permissive" then
      {
        default = "allow";
        scope = "all";
      }
    else
      {
        default = "block";
      };
in
{
  _class = "clan.service";
  manifest = {
    name = "radicle";
    readme = ''
      Radicle - Decentralized code collaboration and repository hosting.

      Radicle is a peer-to-peer code collaboration platform that enables developers to share and collaborate on code without relying on centralized servers.

      **Important**: Each device requires its own unique DID (Decentralized Identifier). Do NOT share Radicle identities across devices. Each machine must run 'rad auth' to create its own identity.

      This service provides three roles:
      - **seed**: Always-online node that replicates and serves repositories
      - **node**: Developer workstation node for active development
      - **gateway**: HTTP gateway for web-based repository browsing (no identity required)

      The service automatically generates SSH key pairs for each instance on each machine to ensure unique DIDs per device.
    '';
  };

  roles = {
    # Seed node - always online, provides availability
    seed = {
      interface = {
        # Freeform module - passes through to services.radicle
        freeformType = attrsOf anything;

        options = {
          # Seed node specific options
          externalAddress = mkOption {
            type = nullOr str;
            default = null;
            description = "External address for the seed node (e.g., seed.example.com:8776)";
          };

          seedingPolicy = mkOption {
            type = enum [
              "permissive"
              "selective"
            ];
            default = "permissive";
            description = "Seeding policy for repositories (default: permissive for seed nodes)";
          };

          # Initial repositories to seed
          initialRepositories = mkOption {
            type = listOf str;
            default = [ ];
            description = "Repository IDs to clone and seed on first startup";
            example = [
              "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5" # heartwood
              "rad:z3trNYnLWS11cJWC6BbxDs5niGo82" # rips
            ];
          };

          # Users who can access the radicle node
          allowedUsers = mkOption {
            type = listOf str;
            default = [ ];
            description = "Users who can access the radicle node via rad commands";
            example = [ "alice" "bob" ];
          };

        };
      };

      perInstance =
        { extendSettings, instanceName, ... }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              userSettings = extendSettings { };

              # Apply mkDefault to user-provided node settings to avoid conflicts
              userNode = userSettings.node or { };
              userHttpd = userSettings.httpd or { };

              localSettings = userSettings // {
                # Use generated SSH keys by default (instance-specific)
                privateKeyFile =
                  mkDefault
                    config.clan.core.vars.generators."radicle-${instanceName}".files.ssh_private_key.path;
                publicKey =
                  mkDefault
                    config.clan.core.vars.generators."radicle-${instanceName}".files.ssh_public_key.path;

                # Seed node defaults
                node = {
                  openFirewall = mkDefault true;
                  listenAddress = mkDefault (userNode.listenAddress or "0.0.0.0");
                  listenPort = mkDefault (userNode.listenPort or 8776);
                }
                // (builtins.removeAttrs userNode [
                  "listenAddress"
                  "listenPort"
                  "openFirewall"
                ]);

                httpd = {
                  enable = mkDefault true;
                  listenAddress = mkDefault (userHttpd.listenAddress or "0.0.0.0");
                  listenPort = mkDefault (userHttpd.listenPort or 8777);
                }
                // (builtins.removeAttrs userHttpd [
                  "listenAddress"
                  "listenPort"
                  "enable"
                ]);
              };

              # Extract our custom options
              inherit (localSettings) externalAddress seedingPolicy initialRepositories allowedUsers;

              # Everything else goes to services.radicle
              radicleConfig = lib.removeAttrs localSettings [
                "externalAddress"
                "seedingPolicy"
                "initialRepositories"
                "allowedUsers"
              ];
            in
            {
              # Use the upstream NixOS radicle service
              services.radicle = radicleConfig // {
                enable = true;

                # Apply our additional settings
                settings = (radicleConfig.settings or { }) // {
                  node = ((radicleConfig.settings or { }).node or { }) // {
                    alias = mkDefault "radicle-seed";
                    seedingPolicy = mkDefault (mkSeedingPolicy seedingPolicy);
                    externalAddresses = mkIf (externalAddress != null) [ externalAddress ];
                  };
                };
              };

              # Service to initialize radicle identity if not exists
              systemd.services.radicle-init-identity = {
                description = "Initialize Radicle identity";
                wantedBy = [ "radicle-node.service" ];
                before = [ "radicle-node.service" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  User = "radicle";
                  Group = "radicle";
                  WorkingDirectory = "/var/lib/radicle";
                };

                script = ''
                  # Check if radicle profile already exists
                  if [ ! -f /var/lib/radicle/.radicle/keys/radicle.pub ]; then
                    echo "Initializing Radicle identity for ${config.networking.hostName}..."
                    # Use non-interactive auth with alias
                    ${config.services.radicle.package}/bin/rad auth --alias "${config.networking.hostName}-${instanceName}" || true
                    echo "Radicle identity initialized with DID: $(${config.services.radicle.package}/bin/rad self --nid || echo 'unknown')"
                  else
                    echo "Radicle identity already exists: $(${config.services.radicle.package}/bin/rad self --nid || echo 'unknown')"
                  fi
                '';

                path = [ config.services.radicle.package ];
              };

              # Ensure radicle-node service starts on boot with hardening
              systemd.services.radicle-node = {
                wantedBy = mkDefault [ "multi-user.target" ];
                after = mkDefault [
                  "network-online.target"
                  "radicle-init-identity.service"
                ];
                wants = mkDefault [
                  "network-online.target"
                  "radicle-init-identity.service"
                ];
                requires = [ "radicle-init-identity.service" ];

                serviceConfig = {
                  # Restart policy for reliability
                  Restart = mkDefault "on-failure";
                  RestartSec = mkDefault "10s";

                  # Resource limits
                  MemoryMax = mkDefault "2G";
                  MemoryHigh = mkDefault "1.5G";
                  CPUQuota = mkDefault "200%"; # Allow 2 cores max

                  # Basic hardening (radicle needs network and storage access)
                  ProtectSystem = mkDefault "strict";
                  ProtectHome = mkDefault true;
                  PrivateTmp = mkDefault true;
                  NoNewPrivileges = mkDefault true;

                  # Allow radicle to write to its state directory
                  ReadWritePaths = mkDefault [ "/var/lib/radicle" ];

                  # Ensure control socket is accessible to users
                  UMask = mkForce "0002"; # Allow group read/write (override upstream)
                };

                # Set permissions on control socket after starting
                postStart = ''
                  # Wait for socket to be created
                  for i in {1..10}; do
                    if [ -S /var/lib/radicle/node/control.sock ]; then
                      chmod 660 /var/lib/radicle/node/control.sock || true
                      break
                    fi
                    sleep 1
                  done
                '';
              };

              # Set up environment for users to connect to system radicle node
              environment.systemPackages = [ config.services.radicle.package ];

              # Allow users to connect to the system radicle node
              users.groups.radicle.members = allowedUsers;

              # Configure rad to use system socket for all users
              environment.variables = {
                RAD_SOCKET = "/var/lib/radicle/node/control.sock";
              };

              # Create wrapper script for rad commands to use system node
              environment.etc."profile.d/radicle.sh".text = ''
                # Point rad commands to system radicle node
                export RAD_SOCKET="/var/lib/radicle/node/control.sock"
                export RAD_HOME="/var/lib/radicle"
              '';

              # Harden httpd service if enabled
              systemd.services.radicle-httpd = {
                after = mkDefault [
                  "network-online.target"
                  "radicle-node.service"
                ];
                wants = mkDefault [ "network-online.target" ];

                serviceConfig = {
                  Restart = mkDefault "on-failure";
                  RestartSec = mkDefault "10s";

                  MemoryMax = mkDefault "512M";
                  MemoryHigh = mkDefault "384M";
                  CPUQuota = mkDefault "100%";

                  ProtectSystem = mkDefault "strict";
                  ProtectHome = mkDefault true;
                  PrivateTmp = mkDefault true;
                  NoNewPrivileges = mkDefault true;

                  ReadWritePaths = mkDefault [ "/var/lib/radicle" ];
                };
              };

              # Service to clone initial repositories with improved retry logic
              systemd.services.radicle-init-repos = mkIf (initialRepositories != [ ]) {
                description = "Initialize Radicle seed repositories";
                after = [
                  "radicle-node.service"
                  "network-online.target"
                ];
                requires = [ "radicle-node.service" ];
                wants = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  User = "radicle";
                  Group = "radicle";
                  WorkingDirectory = "/var/lib/radicle";

                  # Restart if it fails (network might not be ready)
                  Restart = "on-failure";
                  RestartSec = "30s";

                  # Increase timeout for initial clones
                  TimeoutStartSec = "5min";
                };

                script = ''
                  # Wait for node to be ready - check if API responds
                  echo "Waiting for radicle node to be ready..."
                  for i in {1..60}; do
                    if rad self --help >/dev/null 2>&1; then
                      echo "Radicle node is ready"
                      break
                    fi
                    if [ $i -eq 60 ]; then
                      echo "Timeout waiting for radicle node to start"
                      exit 1
                    fi
                    sleep 2
                  done

                  # Clone each repository with retry logic
                  ${concatMapStringsSep "\n" (rid: ''
                    echo "Attempting to clone ${rid}..."
                    if rad ls | grep -q "${rid}"; then
                      echo "${rid} already exists, skipping"
                    else
                      # Try up to 3 times with exponential backoff
                      for attempt in 1 2 3; do
                        echo "Clone attempt $attempt for ${rid}..."
                        if rad clone "${rid}"; then
                          echo "Successfully cloned ${rid}"
                          break
                        else
                          if [ $attempt -lt 3 ]; then
                            wait_time=$((attempt * 10))
                            echo "Clone failed, waiting ''${wait_time}s before retry..."
                            sleep $wait_time
                          else
                            echo "Failed to clone ${rid} after 3 attempts, will retry on next boot"
                          fi
                        fi
                      done
                    fi
                  '') initialRepositories}

                  echo "Repository initialization complete"
                '';

                path = [ config.services.radicle.package ];
              };

              # Create instance-specific vars generator for Radicle SSH keys
              # Each machine gets its own unique DID (Decentralized Identifier)
              clan.core.vars.generators."radicle-${instanceName}" = {
                files.ssh_private_key = {
                  owner = "radicle";
                  group = "radicle";
                  mode = "0600";
                  secret = true; # Mark as secret for proper handling
                  deploy = true; # Deploy to runtime environment
                };
                files.ssh_public_key = {
                  owner = "radicle";
                  group = "radicle";
                  mode = "0644";
                  secret = false; # Public key is not secret
                  deploy = true;
                };
                runtimeInputs = with pkgs; [
                  openssh
                  coreutils
                ];
                script = ''
                  # Generate SSH key pair for Radicle (no passphrase for service automation)
                  # Each device must have its own unique DID - do not share across machines
                  ssh-keygen -t ed25519 -f "$out/ssh_private_key" -N "" -C "radicle-${instanceName}@clan"

                  # Extract public key
                  ssh-keygen -y -f "$out/ssh_private_key" > "$out/ssh_public_key"
                '';
              };

            };
        };
    };

    # Regular node - for developers
    node = {
      interface = {
        # Freeform module - passes through to services.radicle
        freeformType = attrsOf anything;

        options = {
          seedingPolicy = mkOption {
            type = enum [
              "permissive"
              "selective"
            ];
            default = "selective";
            description = "Seeding policy for repositories (default: selective for regular nodes)";
          };

          enableHttpd = mkOption {
            type = bool;
            default = false;
            description = "Enable Radicle HTTP gateway";
          };

          # Users who can access the radicle node
          allowedUsers = mkOption {
            type = listOf str;
            default = [ ];
            description = "Users who can access the radicle node via rad commands";
            example = [ "alice" "bob" ];
          };

        };
      };

      perInstance =
        { extendSettings, instanceName, ... }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              userSettings = extendSettings { };

              # Apply mkDefault to user-provided node settings to avoid conflicts
              userNode = userSettings.node or { };
              userHttpd = userSettings.httpd or { };

              localSettings = userSettings // {
                # Use generated SSH keys by default (instance-specific)
                privateKeyFile =
                  mkDefault
                    config.clan.core.vars.generators."radicle-${instanceName}".files.ssh_private_key.path;
                publicKey =
                  mkDefault
                    config.clan.core.vars.generators."radicle-${instanceName}".files.ssh_public_key.path;

                # Regular node defaults
                node = {
                  openFirewall = mkDefault false;
                  listenAddress = mkDefault (userNode.listenAddress or "127.0.0.1");
                  listenPort = mkDefault (userNode.listenPort or 8776);
                }
                // (builtins.removeAttrs userNode [
                  "listenAddress"
                  "listenPort"
                  "openFirewall"
                ]);

                httpd = {
                  enable = mkDefault (userSettings.enableHttpd or false);
                  listenAddress = mkDefault (userHttpd.listenAddress or "127.0.0.1");
                  listenPort = mkDefault (userHttpd.listenPort or 8777);
                }
                // (builtins.removeAttrs userHttpd [
                  "listenAddress"
                  "listenPort"
                  "enable"
                ]);
              };

              # Extract our custom options
              inherit (localSettings) seedingPolicy allowedUsers;

              # Everything else goes to services.radicle
              radicleConfig = lib.removeAttrs localSettings [
                "seedingPolicy"
                "enableHttpd"
                "allowedUsers"
              ];
            in
            {
              # Use the upstream NixOS radicle service
              services.radicle = radicleConfig // {
                enable = true;

                # Apply our additional settings
                settings = (radicleConfig.settings or { }) // {
                  node = ((radicleConfig.settings or { }).node or { }) // {
                    alias = mkDefault "radicle-node";
                    seedingPolicy = mkDefault (mkSeedingPolicy seedingPolicy);
                  };
                };
              };

              # Service to initialize radicle identity if not exists
              systemd.services.radicle-init-identity = {
                description = "Initialize Radicle identity";
                wantedBy = [ "radicle-node.service" ];
                before = [ "radicle-node.service" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  User = "radicle";
                  Group = "radicle";
                  WorkingDirectory = "/var/lib/radicle";
                };

                script = ''
                  # Check if radicle profile already exists
                  if [ ! -f /var/lib/radicle/.radicle/keys/radicle.pub ]; then
                    echo "Initializing Radicle identity for ${config.networking.hostName}..."
                    # Use non-interactive auth with alias
                    ${config.services.radicle.package}/bin/rad auth --alias "${config.networking.hostName}-${instanceName}" || true
                    echo "Radicle identity initialized with DID: $(${config.services.radicle.package}/bin/rad self --nid || echo 'unknown')"
                  else
                    echo "Radicle identity already exists: $(${config.services.radicle.package}/bin/rad self --nid || echo 'unknown')"
                  fi
                '';

                path = [ config.services.radicle.package ];
              };

              # Ensure radicle-node service starts on boot with hardening
              systemd.services.radicle-node = {
                wantedBy = mkDefault [ "multi-user.target" ];
                after = mkDefault [
                  "network-online.target"
                  "radicle-init-identity.service"
                ];
                wants = mkDefault [
                  "network-online.target"
                  "radicle-init-identity.service"
                ];
                requires = [ "radicle-init-identity.service" ];

                serviceConfig = {
                  # Restart policy for reliability
                  Restart = mkDefault "on-failure";
                  RestartSec = mkDefault "10s";

                  # Resource limits (lighter for regular nodes)
                  MemoryMax = mkDefault "1G";
                  MemoryHigh = mkDefault "768M";
                  CPUQuota = mkDefault "150%";

                  # Basic hardening
                  ProtectSystem = mkDefault "strict";
                  ProtectHome = mkDefault true;
                  PrivateTmp = mkDefault true;
                  NoNewPrivileges = mkDefault true;

                  # Allow radicle to write to its state directory
                  ReadWritePaths = mkDefault [ "/var/lib/radicle" ];

                  # Ensure control socket is accessible to users
                  UMask = mkForce "0002"; # Allow group read/write (override upstream)
                };

                # Set permissions on control socket after starting
                postStart = ''
                  # Wait for socket to be created
                  for i in {1..10}; do
                    if [ -S /var/lib/radicle/node/control.sock ]; then
                      chmod 660 /var/lib/radicle/node/control.sock || true
                      break
                    fi
                    sleep 1
                  done
                '';
              };

              # Set up environment for users to connect to system radicle node
              environment.systemPackages = [ config.services.radicle.package ];

              # Allow users to connect to the system radicle node
              users.groups.radicle.members = allowedUsers;

              # Configure rad to use system socket for all users
              environment.variables = {
                RAD_SOCKET = "/var/lib/radicle/node/control.sock";
              };

              # Create wrapper script for rad commands to use system node
              environment.etc."profile.d/radicle.sh".text = ''
                # Point rad commands to system radicle node
                export RAD_SOCKET="/var/lib/radicle/node/control.sock"
                export RAD_HOME="/var/lib/radicle"
              '';

              # Harden httpd service if enabled
              systemd.services.radicle-httpd = {
                after = mkDefault [
                  "network-online.target"
                  "radicle-node.service"
                ];
                wants = mkDefault [ "network-online.target" ];

                serviceConfig = {
                  Restart = mkDefault "on-failure";
                  RestartSec = mkDefault "10s";

                  MemoryMax = mkDefault "512M";
                  MemoryHigh = mkDefault "384M";
                  CPUQuota = mkDefault "100%";

                  ProtectSystem = mkDefault "strict";
                  ProtectHome = mkDefault true;
                  PrivateTmp = mkDefault true;
                  NoNewPrivileges = mkDefault true;

                  ReadWritePaths = mkDefault [ "/var/lib/radicle" ];
                };
              };

              # Create instance-specific vars generator for Radicle SSH keys
              # Each machine gets its own unique DID (Decentralized Identifier)
              clan.core.vars.generators."radicle-${instanceName}" = {
                files.ssh_private_key = {
                  owner = "radicle";
                  group = "radicle";
                  mode = "0600";
                  secret = true; # Mark as secret for proper handling
                  deploy = true; # Deploy to runtime environment
                };
                files.ssh_public_key = {
                  owner = "radicle";
                  group = "radicle";
                  mode = "0644";
                  secret = false; # Public key is not secret
                  deploy = true;
                };
                runtimeInputs = with pkgs; [
                  openssh
                  coreutils
                ];
                script = ''
                  # Generate SSH key pair for Radicle (no passphrase for service automation)
                  # Each device must have its own unique DID - do not share across machines
                  ssh-keygen -t ed25519 -f "$out/ssh_private_key" -N "" -C "radicle-${instanceName}@clan"

                  # Extract public key
                  ssh-keygen -y -f "$out/ssh_private_key" > "$out/ssh_public_key"
                '';
              };

            };
        };
    };

    # HTTP gateway only - lightweight web access
    gateway = {
      interface = {
        # Freeform module for httpd configuration
        freeformType = attrsOf anything;

        options = {
          nodeAddress = mkOption {
            type = str;
            default = "127.0.0.1:8776";
            description = "Address of the Radicle node to connect to";
          };

          openFirewall = mkOption {
            type = bool;
            default = false;
            description = "Open firewall for HTTP gateway";
          };
        };
      };

      perInstance =
        { extendSettings, instanceName, ... }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              localSettings = extendSettings {
                listenPort = mkDefault 8777;
                listenAddress = mkDefault "127.0.0.1";
              };

              inherit (localSettings) nodeAddress openFirewall;
              httpdConfig = lib.removeAttrs localSettings [
                "nodeAddress"
                "openFirewall"
              ];
            in
            {
              # Gateway role: enable radicle service but mask the node, only run httpd
              services.radicle = {
                enable = true;
                # Minimal node config (won't actually run)
                node.listenAddress = "127.0.0.1";
                node.listenPort = 8776;
                node.openFirewall = false;
                # Use generated SSH keys (instance-specific)
                privateKeyFile =
                  mkDefault
                    config.clan.core.vars.generators."radicle-${instanceName}".files.ssh_private_key.path;
                publicKey =
                  mkDefault
                    config.clan.core.vars.generators."radicle-${instanceName}".files.ssh_public_key.path;
                # Enable httpd gateway
                httpd = httpdConfig // {
                  enable = true;
                  extraArgs = [
                    "--node"
                    nodeAddress
                  ]
                  ++ (httpdConfig.extraArgs or [ ]);
                };
              };

              # Disable the node service, only run httpd
              systemd.services.radicle-node.enable = mkForce false;

              # Harden the httpd service
              systemd.services.radicle-httpd = {
                after = mkDefault [ "network-online.target" ];
                wants = mkDefault [ "network-online.target" ];

                serviceConfig = {
                  Restart = mkDefault "on-failure";
                  RestartSec = mkDefault "10s";

                  # Resource limits (httpd is lightweight)
                  MemoryMax = mkDefault "512M";
                  MemoryHigh = mkDefault "384M";
                  CPUQuota = mkDefault "100%";

                  # Hardening
                  ProtectSystem = mkDefault "strict";
                  ProtectHome = mkDefault true;
                  PrivateTmp = mkDefault true;
                  NoNewPrivileges = mkDefault true;

                  ReadWritePaths = mkDefault [ "/var/lib/radicle" ];
                };
              };

              # Firewall rules for httpd if requested
              networking.firewall.allowedTCPPorts = mkIf openFirewall [
                localSettings.listenPort
              ];

              # Create instance-specific vars generator for Radicle SSH keys
              # Even gateway needs keys to authenticate with radicle node
              clan.core.vars.generators."radicle-${instanceName}" = {
                files.ssh_private_key = {
                  owner = "radicle";
                  group = "radicle";
                  mode = "0600";
                  secret = true; # Mark as secret for proper handling
                  deploy = true; # Deploy to runtime environment
                };
                files.ssh_public_key = {
                  owner = "radicle";
                  group = "radicle";
                  mode = "0644";
                  secret = false; # Public key is not secret
                  deploy = true;
                };
                runtimeInputs = with pkgs; [
                  openssh
                  coreutils
                ];
                script = ''
                  # Generate SSH key pair for Radicle (no passphrase for service automation)
                  # Each device must have its own unique DID - do not share across machines
                  ssh-keygen -t ed25519 -f "$out/ssh_private_key" -N "" -C "radicle-${instanceName}@clan"

                  # Extract public key
                  ssh-keygen -y -f "$out/ssh_private_key" > "$out/ssh_public_key"
                '';
              };

            };
        };
    };
  };

  # Common configuration for all machines with radicle
  # NOTE: We intentionally do NOT use perMachine here because we need instance-specific naming
  # Each instance will generate its own keys per machine (not shared across machines due to Radicle's DID requirement)
  perMachine = _: {
    nixosModule = _: { };
  };
}
