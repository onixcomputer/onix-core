{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "iroh-ssh";
    description = "P2P SSH via Iroh - SSH to machines without public IPs, port forwarding, or VPN";
    readme = "Iroh-based peer-to-peer SSH using QUIC/UDP hole-punching for NAT traversal";
    categories = [
      "Networking"
      "SSH"
    ];
  };

  roles.peer = {
    description = "Iroh SSH peer that runs the iroh-ssh server for incoming connections";
    interface = mkSettings.mkInterface schema.peer;

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
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            cfg = extendSettings (ms.mkDefaults schema.peer);
            iroh-ssh = pkgs.callPackage ../../pkgs/iroh-ssh { };
          in
          {
            assertions = [
              {
                assertion = config.services.openssh.enable or false;
                message = "iroh-ssh: requires openssh to be enabled (services.openssh.enable = true) — iroh-ssh forwards incoming connections to local sshd on port ${toString cfg.sshPort}";
              }
            ];

            clan.core.vars.generators."iroh-ssh" = {
              files = {
                "irohssh_ed25519" = { };
                "irohssh_ed25519.pub".secret = false;
                "node-id".secret = false;
              };

              runtimeInputs = [
                (pkgs.python3.withPackages (ps: [ ps.cryptography ]))
              ];

              script = ''
                python3 -c "
                import base64, os
                from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
                from cryptography.hazmat.primitives import serialization

                Z32 = 'ybndrfg8ejkmcpqxot1uwisza345h769'
                STD = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'

                def z32_encode(data):
                    b32 = base64.b32encode(data).decode().rstrip('=')
                    return b32.translate(str.maketrans(STD + STD.lower(), Z32 + Z32))

                key = Ed25519PrivateKey.generate()
                priv_bytes = key.private_bytes(
                    serialization.Encoding.Raw,
                    serialization.PrivateFormat.Raw,
                    serialization.NoEncryption(),
                )
                pub_bytes = key.public_key().public_bytes(
                    serialization.Encoding.Raw,
                    serialization.PublicFormat.Raw,
                )

                with open(os.environ['out'] + '/irohssh_ed25519', 'w') as f:
                    f.write(z32_encode(priv_bytes))
                with open(os.environ['out'] + '/irohssh_ed25519.pub', 'w') as f:
                    f.write(z32_encode(pub_bytes))
                with open(os.environ['out'] + '/node-id', 'w') as f:
                    f.write(pub_bytes.hex())
                "
              '';
            };

            systemd.services."iroh-ssh" = {
              description = "iroh-ssh server";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [
                "network-online.target"
                "sshd.service"
              ];

              serviceConfig = {
                Type = "simple";
                User = "iroh-ssh";
                Group = "iroh-ssh";
                StateDirectory = "iroh-ssh";

                ExecStartPre =
                  let
                    script = pkgs.writeShellApplication {
                      name = "iroh-ssh-setup-keys";
                      runtimeInputs = [ pkgs.coreutils ];
                      text = ''
                        mkdir -p /var/lib/iroh-ssh/.ssh
                        install -o iroh-ssh -g iroh-ssh -m 0600 \
                          ${config.clan.core.vars.generators."iroh-ssh".files."irohssh_ed25519".path} \
                          /var/lib/iroh-ssh/.ssh/irohssh_ed25519
                        install -o iroh-ssh -g iroh-ssh -m 0644 \
                          ${config.clan.core.vars.generators."iroh-ssh".files."irohssh_ed25519.pub".path} \
                          /var/lib/iroh-ssh/.ssh/irohssh_ed25519.pub
                      '';
                    };
                  in
                  "+${lib.getExe script}";

                ExecStart = "${iroh-ssh}/bin/iroh-ssh server --persist --ssh-port ${toString cfg.sshPort}";
                Environment = "HOME=/var/lib/iroh-ssh";
                Restart = "on-failure";
                RestartSec = "10s";

                PrivateTmp = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                NoNewPrivileges = true;
              };
            };

            users.users.iroh-ssh = {
              isSystemUser = true;
              group = "iroh-ssh";
              home = "/var/lib/iroh-ssh";
            };
            users.groups.iroh-ssh = { };

            environment.systemPackages = [ iroh-ssh ];
          };
      };
  };
}
