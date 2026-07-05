{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };

  generatorPrefix = "iroh-ssh-";
  serviceName = "iroh-ssh";
  serviceUser = serviceName;
  serviceGroup = serviceName;
  stateDirectoryName = serviceName;
  stateHome = "/var/lib/${stateDirectoryName}";
  sshDirectory = "${stateHome}/.ssh";
  privateKeyFileName = "irohssh_ed25519";
  publicKeyFileName = "${privateKeyFileName}.pub";
  nodeIdFileName = "node-id";
  privateKeyMode = "0600";
  publicKeyMode = "0644";
  restartDelay = "10s";

  mkGeneratorName =
    instanceName:
    if lib.hasPrefix generatorPrefix instanceName then
      instanceName
    else
      "${generatorPrefix}${instanceName}";
in
{
  _class = "clan.service";

  manifest = {
    name = serviceName;
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
      { instanceName, extendSettings, ... }:
      let
        generatorName = mkGeneratorName instanceName;
      in
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
            irohSsh = pkgs.callPackage ../../pkgs/iroh-ssh { };
            setupKeys = pkgs.writeShellApplication {
              name = "${serviceName}-setup-keys";
              runtimeInputs = [ pkgs.coreutils ];
              text = ''
                mkdir -p ${sshDirectory}
                install -o ${serviceUser} -g ${serviceGroup} -m ${privateKeyMode} \
                  ${config.clan.core.vars.generators."${generatorName}".files."${privateKeyFileName}".path} \
                  ${sshDirectory}/${privateKeyFileName}
                install -o ${serviceUser} -g ${serviceGroup} -m ${publicKeyMode} \
                  ${config.clan.core.vars.generators."${generatorName}".files."${publicKeyFileName}".path} \
                  ${sshDirectory}/${publicKeyFileName}
              '';
            };
          in
          {
            assertions = [
              {
                assertion = config.services.openssh.enable or false;
                message = "${serviceName}: requires openssh to be enabled (services.openssh.enable = true) — iroh-ssh forwards incoming connections to local sshd on port ${toString cfg.sshPort}";
              }
            ];

            clan.core.vars.generators."${generatorName}" = {
              files = {
                "${privateKeyFileName}" = { };
                "${publicKeyFileName}".secret = false;
                "${nodeIdFileName}".secret = false;
              };

              runtimeInputs = [
                (pkgs.python3.withPackages (pythonPackages: [ pythonPackages.cryptography ]))
              ];

              script = ''
                python3 <<'PY'
                import base64
                import os

                from cryptography.hazmat.primitives import serialization
                from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

                ZBASE32_ALPHABET = "ybndrfg8ejkmcpqxot1uwisza345h769"
                STANDARD_BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

                translation_table = str.maketrans(
                    STANDARD_BASE32_ALPHABET + STANDARD_BASE32_ALPHABET.lower(),
                    ZBASE32_ALPHABET + ZBASE32_ALPHABET,
                )

                def zbase32_encode(data):
                    base32_text = base64.b32encode(data).decode().rstrip("=")
                    return base32_text.translate(translation_table)

                output_directory = os.environ["out"]
                key = Ed25519PrivateKey.generate()
                private_key_bytes = key.private_bytes(
                    serialization.Encoding.Raw,
                    serialization.PrivateFormat.Raw,
                    serialization.NoEncryption(),
                )
                public_key_bytes = key.public_key().public_bytes(
                    serialization.Encoding.Raw,
                    serialization.PublicFormat.Raw,
                )

                with open(os.path.join(output_directory, "${privateKeyFileName}"), "w", encoding="utf-8") as file:
                    file.write(zbase32_encode(private_key_bytes))
                with open(os.path.join(output_directory, "${publicKeyFileName}"), "w", encoding="utf-8") as file:
                    file.write(zbase32_encode(public_key_bytes))
                with open(os.path.join(output_directory, "${nodeIdFileName}"), "w", encoding="utf-8") as file:
                    file.write(public_key_bytes.hex())
                PY
              '';
            };

            systemd.services."${serviceName}" = {
              description = "iroh-ssh server";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [
                "network-online.target"
                "sshd.service"
              ];

              serviceConfig = {
                Type = "simple";
                User = serviceUser;
                Group = serviceGroup;
                StateDirectory = stateDirectoryName;

                ExecStartPre = "+${lib.getExe setupKeys}";
                ExecStart = "${lib.getExe irohSsh} server --persist --ssh-port ${toString cfg.sshPort}";
                Environment = "HOME=${stateHome}";
                Restart = "on-failure";
                RestartSec = restartDelay;

                PrivateTmp = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                NoNewPrivileges = true;
              };
            };

            users.users."${serviceUser}" = {
              isSystemUser = true;
              group = serviceGroup;
              home = stateHome;
            };
            users.groups."${serviceGroup}" = { };

            environment.systemPackages = [ irohSsh ];
          };
      };
  };
}
