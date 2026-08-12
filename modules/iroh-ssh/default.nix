{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };

  generatorPrefix = "iroh-ssh-";
  serviceName = "iroh-ssh";
  privateKeyFileName = "irohssh_ed25519";
  publicKeyFileName = "${privateKeyFileName}.pub";
  nodeIdFileName = "node-id";

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
            settings = extendSettings (ms.mkDefaults schema.peer);
            privateKeyPath = config.clan.core.vars.generators.${generatorName}.files.${privateKeyFileName}.path;
            publicKeyPath = config.clan.core.vars.generators.${generatorName}.files.${publicKeyFileName}.path;
            serviceConfig = import ./mk-nixos-config.nix {
              inherit
                config
                lib
                pkgs
                privateKeyPath
                publicKeyPath
                settings
                ;
            };
          in
          lib.mkMerge [
            serviceConfig
            {
              clan.core.vars.generators.${generatorName} = {
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
            }
          ];
      };
  };
}
