{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    types
    removeAttrs
    ;
in
{
  _class = "clan.service";
  manifest.name = "harmonia";

  roles = {
    client = {
      interface =
        { lib, ... }:
        {
          options = {
            serverUrl = lib.mkOption {
              type = lib.types.str;
              description = "The URL of the harmonia server";
              example = "http://britton-fw:5000";
            };

            priority = lib.mkOption {
              type = lib.types.int;
              default = 30;
              description = "Priority of this binary cache (lower is higher priority)";
            };

            extraSubstituters = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "https://nix-community.cachix.org"
                "https://cache.nixos.org/"
              ];
              description = "Additional substituters to use";
            };

            extraTrustedPublicKeys = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              ];
              description = "Additional trusted public keys";
            };
          };
        };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, lib, ... }:
            let
              settings = extendSettings { };
            in
            {
              #I dont think this is needed - need to test and confirm.
              # Declare the shared generator on the client
              clan.core.vars.generators.harmonia-signing-key = {
                share = true;
                prompts = { }; # No prompts needed for clients
                migrateFact = "harmonia-signing-key";
                # Clients don't need the generation script - they just reference the shared key
                files = {
                  "signing-key.pub" = {
                    secret = false;
                  };
                };
              };

              nix.settings = {
                substituters = lib.mkBefore ([ settings.serverUrl ] ++ settings.extraSubstituters);
                trusted-public-keys = lib.mkBefore (
                  [
                    config.clan.core.vars.generators.harmonia-signing-key.files."signing-key.pub".value
                  ]
                  ++ settings.extraTrustedPublicKeys
                );
              };
            };
        };
    };

    server = {
      interface =
        { lib, ... }:
        {
          freeformType = with lib.types; attrsOf anything;

          options = {
            subdomain = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Subdomain to use for Harmonia (requires tailscale-traefik to be enabled)";
            };

            enableNginx = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable nginx reverse proxy for Harmonia";
            };

            priority = lib.mkOption {
              type = lib.types.int;
              default = 30;
              description = "Priority of this binary cache (lower is higher priority)";
            };

            generateSigningKey = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Automatically generate a signing key for the binary cache";
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
              settings = extendSettings {
                # Default settings
                settings = mkDefault {
                  bind = mkDefault "[::]:5000";
                  priority = mkDefault settings.priority or 30;
                };
              };

              # Extract clan options
              inherit (settings)
                subdomain
                enableNginx
                priority
                generateSigningKey
                ;

              # Remove clan options from serviceConfig
              serviceConfig = builtins.removeAttrs settings [
                "subdomain"
                "enableNginx"
                "priority"
                "generateSigningKey"
              ];

              # Ensure priority is in the right place and add signing key if needed
              harmoniaConfig = serviceConfig // {
                settings = (serviceConfig.settings or { }) // {
                  priority = mkDefault priority;
                };
                signKeyPaths = lib.mkIf generateSigningKey [
                  config.clan.core.vars.generators.harmonia-signing-key.files."signing-key.sec".path
                ];
              };
            in
            {
              services.harmonia = lib.mkMerge [
                { enable = true; }
                harmoniaConfig
              ];

              # Generate signing key if requested
              clan.core.vars.generators = lib.mkIf generateSigningKey {
                harmonia-signing-key = {
                  share = true;
                  prompts = { }; # No prompts for auto-generation
                  migrateFact = "harmonia-signing-key";
                  runtimeInputs = [
                    pkgs.nix
                    pkgs.hostname
                    pkgs.coreutils
                  ];
                  script = ''
                    # Generate a new signing key pair for the binary cache
                    ${pkgs.nix}/bin/nix-store --generate-binary-cache-key \
                      "harmonia-$(${pkgs.hostname}/bin/hostname)-$(date +%s)" \
                      "$out"/signing-key.sec \
                      "$out"/signing-key.pub
                      
                    # Remove trailing newline from public key
                    ${pkgs.coreutils}/bin/tr -d '\n' < "$out"/signing-key.pub > "$out"/signing-key.pub.tmp
                    mv "$out"/signing-key.pub.tmp "$out"/signing-key.pub

                    # Also store the public key separately for easy access
                    cp "$out"/signing-key.pub "$out"/public-key
                  '';
                  files = {
                    "signing-key.sec" = {
                      owner = "harmonia";
                      group = "harmonia";
                      mode = "0400";
                    };
                    "signing-key.pub" = {
                      secret = false;
                    };
                  };
                };
              };

              # Note: If using subdomain, ensure tailscale-traefik is configured for this machine
              # and add harmonia to its services configuration

              # Basic nginx configuration if enabled (without tailscale)
              services.nginx = lib.mkIf (enableNginx && subdomain == null) {
                enable = true;
                virtualHosts."harmonia" = {
                  locations."/" = {
                    proxyPass = "http://[::1]:5000";
                    proxyWebsockets = true;
                    extraConfig = ''
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;

                      # Allow large file uploads for nix store paths
                      client_max_body_size 0;

                      # Increase timeouts for large file transfers
                      proxy_read_timeout 300s;
                      proxy_send_timeout 300s;
                    '';
                  };
                };
              };

              # Open firewall port
              networking.firewall.allowedTCPPorts = [ 5000 ];

              # Ensure harmonia user/group exists
              users.users.harmonia = {
                isSystemUser = true;
                group = "harmonia";
                description = "Harmonia binary cache daemon";
              };
              users.groups.harmonia = { };
            };
        };
    };
  };
}
