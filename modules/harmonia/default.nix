{ lib, ... }:
let
  inherit (lib)
    mkDefault
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
        { extendSettings, instanceName, ... }:
        {
          nixosModule =
            { config, lib, ... }:
            let
              settings = extendSettings { };
            in
            {
              clan.core.vars.generators."harmonia-${instanceName}" = {
                share = true;
                prompts = { };
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
                    config.clan.core.vars.generators."harmonia-${instanceName}".files."signing-key.pub".value
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

            enableCIPush = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable CI push access to this Harmonia cache via SSH";
            };

            ciDeployUser = lib.mkOption {
              type = lib.types.str;
              default = "ci-deploy";
              description = "Username for CI deployments to push to this cache";
            };
          };
        };

      perInstance =
        { extendSettings, instanceName, ... }:
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
                settings = mkDefault {
                  bind = mkDefault "[::]:5000";
                  priority = mkDefault settings.priority or 30;
                };
              };

              inherit (settings)
                subdomain
                enableNginx
                priority
                generateSigningKey
                enableCIPush
                ciDeployUser
                ;

              serviceConfig = builtins.removeAttrs settings [
                "subdomain"
                "enableNginx"
                "priority"
                "generateSigningKey"
                "enableCIPush"
                "ciDeployUser"
              ];

              harmoniaConfig = serviceConfig // {
                settings = (serviceConfig.settings or { }) // {
                  priority = mkDefault priority;
                };
                signKeyPaths = lib.mkIf generateSigningKey [
                  config.clan.core.vars.generators."harmonia-${instanceName}".files."signing-key.sec".path
                ];
              };
            in
            {
              services = {
                harmonia = lib.mkMerge [
                  { enable = true; }
                  harmoniaConfig
                ];

                # Restrict CI deploy user to only nix operations via SSH
                openssh.extraConfig = lib.mkIf enableCIPush ''
                  Match User ${ciDeployUser}
                    ForceCommand ${pkgs.nix}/bin/nix-store --serve --write
                    AllowTcpForwarding no
                    X11Forwarding no
                    PermitTTY no
                    PermitTunnel no
                '';

                nginx = lib.mkIf (enableNginx && subdomain == null) {
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
              };

              clan.core.vars.generators = lib.mkIf generateSigningKey {
                "harmonia-${instanceName}" = {
                  share = true;
                  prompts = { };
                  runtimeInputs = [
                    pkgs.nix
                    pkgs.hostname
                    pkgs.coreutils
                  ];
                  script = ''
                    ${pkgs.nix}/bin/nix-store --generate-binary-cache-key \
                      "harmonia-$(${pkgs.hostname}/bin/hostname)-$(date +%s)" \
                      "$out"/signing-key.sec \
                      "$out"/signing-key.pub
                    # Remove trailing newline from public key
                    ${pkgs.coreutils}/bin/tr -d '\n' < "$out"/signing-key.pub > "$out"/signing-key.pub.tmp
                    mv "$out"/signing-key.pub.tmp "$out"/signing-key.pub
                    cp "$out"/signing-key.pub "$out"/public-key
                  '';
                  files = {
                    "signing-key.sec" = {
                      owner = "harmonia";
                      group = "harmonia";
                      mode = "0400";
                      deploy = true;
                    };
                    "signing-key.pub" = {
                      secret = false;
                      deploy = true;
                    };
                  };
                };

                "harmonia-ci-${instanceName}" = lib.mkIf enableCIPush {
                  share = false;
                  runtimeInputs = [
                    pkgs.openssh
                    pkgs.coreutils
                  ];
                  script = ''
                    ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f "$out"/ci-deploy-key -C "harmonia-ci-${instanceName}"

                    # Also store the public key with .pub extension for consistency
                    cp "$out"/ci-deploy-key.pub "$out"/ssh-key.pub
                  '';
                  files = {
                    "ci-deploy-key" = {
                      owner = "root";
                      group = "root";
                      mode = "0400";
                      deploy = false;
                    };
                    "ci-deploy-key.pub" = {
                      secret = false;
                      deploy = true;
                    };
                    "ssh-key.pub" = {
                      secret = false;
                      deploy = false;
                    };
                  };
                };
              };

              users = {
                users = {
                  ${ciDeployUser} = lib.mkIf enableCIPush {
                    isSystemUser = true;
                    group = ciDeployUser;
                    description = "CI deployment user for Harmonia cache";
                    home = "/var/lib/${ciDeployUser}";
                    createHome = true;
                    shell = pkgs.bash;
                    openssh.authorizedKeys.keys = [
                      config.clan.core.vars.generators."harmonia-ci-${instanceName}".files."ci-deploy-key.pub".value
                    ];
                  };

                  harmonia = {
                    isSystemUser = true;
                    group = "harmonia";
                    description = "Harmonia binary cache daemon";
                  };
                };

                groups = {
                  ${ciDeployUser} = lib.mkIf enableCIPush { };
                  harmonia = { };
                };
              };

              # Allow CI deploy user to write to nix store
              nix.settings.trusted-users = lib.mkIf enableCIPush [ ciDeployUser ];

              networking.firewall.allowedTCPPorts =
                let
                  bindStr = harmoniaConfig.settings.bind or "[::]:5000";
                  portStr = lib.last (lib.splitString ":" bindStr);
                  port = lib.toInt portStr;
                in
                [ port ];
            };
        };
    };
  };
}
