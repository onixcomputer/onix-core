{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkIf
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
in
{
  _class = "clan.service";
  manifest.name = "radicle";

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

        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, ... }:
            let
              userSettings = extendSettings { };

              localSettings = userSettings // {
                # Use generated SSH keys by default
                privateKeyFile = mkDefault config.clan.core.vars.generators.radicle.files.ssh_private_key.path;
                publicKey = mkDefault config.clan.core.vars.generators.radicle.files.ssh_public_key.path;

                # Seed node defaults
                node = {
                  openFirewall = mkDefault true;
                }
                // (userSettings.node or { });

                httpd = {
                  enable = mkDefault true;
                }
                // (userSettings.httpd or { });
              };

              # Extract our custom options
              inherit (localSettings) externalAddress seedingPolicy initialRepositories;

              # Everything else goes to services.radicle
              radicleConfig = removeAttrs localSettings [
                "externalAddress"
                "seedingPolicy"
                "initialRepositories"
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
                    listen = mkDefault [ "0.0.0.0:8776" ];
                    seedingPolicy =
                      if seedingPolicy == "permissive" then
                        {
                          default = "allow";
                          scope = "all";
                        }
                      else
                        {
                          default = "block";
                        };
                    externalAddresses = mkIf (externalAddress != null) [ externalAddress ];
                  };
                };
              };

              # Service to clone initial repositories
              systemd.services.radicle-init-repos = mkIf (initialRepositories != [ ]) {
                description = "Initialize Radicle seed repositories";
                after = [ "radicle-node.service" ];
                requires = [ "radicle-node.service" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  User = "radicle";
                  Group = "radicle";
                  WorkingDirectory = "/var/lib/radicle";
                };

                script = ''
                  # Wait for node to be ready
                  sleep 10

                  # Clone each repository
                  ${concatMapStringsSep "\n" (rid: ''
                    echo "Attempting to clone ${rid}..."
                    if ! rad ls | grep -q "${rid}"; then
                      rad clone "${rid}" || echo "Failed to clone ${rid}, will retry on next connection"
                    else
                      echo "${rid} already exists"
                    fi
                  '') initialRepositories}
                '';

                path = [ config.services.radicle.package ];
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

        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, ... }:
            let
              userSettings = extendSettings { };

              localSettings = userSettings // {
                # Use generated SSH keys by default
                privateKeyFile = mkDefault config.clan.core.vars.generators.radicle.files.ssh_private_key.path;
                publicKey = mkDefault config.clan.core.vars.generators.radicle.files.ssh_public_key.path;

                # Regular node defaults
                node = {
                  openFirewall = mkDefault false;
                }
                // (userSettings.node or { });

                httpd = {
                  enable = userSettings.enableHttpd or false;
                }
                // (userSettings.httpd or { });
              };

              # Extract our custom options
              inherit (localSettings) seedingPolicy;

              # Everything else goes to services.radicle
              radicleConfig = removeAttrs localSettings [
                "seedingPolicy"
                "enableHttpd"
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
                    listen = mkDefault [ "127.0.0.1:8776" ];
                    seedingPolicy =
                      if seedingPolicy == "permissive" then
                        {
                          default = "allow";
                          scope = "all";
                        }
                      else
                        {
                          default = "block";
                        };
                  };
                };
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
        { extendSettings, ... }:
        {
          nixosModule =
            _:
            let
              localSettings = extendSettings {
                listenPort = mkDefault 8777;
                listenAddress = mkDefault "127.0.0.1";
              };

              inherit (localSettings) nodeAddress openFirewall;
              httpdConfig = removeAttrs localSettings [
                "nodeAddress"
                "openFirewall"
              ];
            in
            {
              # Only enable httpd, not the full node
              services.radicle = {
                enable = false;
                httpd = httpdConfig // {
                  enable = true;
                  extraArgs = [
                    "--node"
                    nodeAddress
                  ]
                  ++ (httpdConfig.extraArgs or [ ]);
                };
              };

              # Firewall rules for httpd if requested
              networking.firewall.allowedTCPPorts = mkIf openFirewall [
                localSettings.listenPort
              ];
            };
        };
    };
  };

  # Common configuration for all machines with radicle
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        # Create vars generator for Radicle SSH keys
        # Note: The radicle user is created by the upstream NixOS module
        clan.core.vars.generators.radicle = {
          files.ssh_private_key = {
            owner = "radicle";
            group = "radicle";
            mode = "0600";
          };
          files.ssh_public_key = {
            owner = "radicle";
            group = "radicle";
            mode = "0644";
          };
          runtimeInputs = with pkgs; [
            openssh
            coreutils
          ];
          script = ''
            # Generate SSH key pair for Radicle (no passphrase for seed nodes)
            ssh-keygen -t ed25519 -f "$out/ssh_private_key" -N "" -C "radicle@clan"

            # Extract public key
            ssh-keygen -y -f "$out/ssh_private_key" > "$out/ssh_public_key"
          '';
        };

      };
  };
}
