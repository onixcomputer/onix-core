# r[impl onix.radicle_node.hosting]
{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  validateSettings = import ./validate-settings.nix { inherit lib; };
  mkNixosConfig = import ./mk-nixos-config.nix { inherit lib; };

  generatorPrefix = "radicle-node-";
  privateKeyFileName = "node-private-key";
  publicKeyFileName = "node-public-key";
  privateKeyMode = "0400";
  publicKeyMode = "0444";
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
    name = "radicle-node";
    readme = "Selective least-authority Radicle seed and read-only HTTP gateway";
    description = "Runs the reviewed Radicle bootstrap node behind typed Onix policy";
    categories = [
      "Development"
      "Network"
    ];
  };

  roles.default = {
    description = "Selective Radicle bootstrap seed";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { instanceName, extendSettings, ... }:
      let
        generatorName = mkGeneratorName instanceName;
      in
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.default);
            nodePackage = pkgs.radicle-node;
            httpdPackage = pkgs.radicle-httpd;
            identityFiles = config.clan.core.vars.generators.${generatorName}.files;
            privateKeyPath = identityFiles.${privateKeyFileName}.path;
            publicKeyPath = identityFiles.${publicKeyFileName}.path;
            validationErrors = validateSettings {
              inherit settings;
              packageVersion = nodePackage.version;
              actualHost = config.networking.hostName;
            };
            loweredConfig = mkNixosConfig {
              inherit
                settings
                nodePackage
                httpdPackage
                privateKeyPath
                publicKeyPath
                ;
            };
          in
          lib.mkMerge [
            loweredConfig
            {
              assertions = map (message: {
                assertion = false;
                message = "radicle-node-${instanceName}: ${message}";
              }) validationErrors;

              clan.core.vars.generators.${generatorName} = {
                files = {
                  ${privateKeyFileName} = {
                    secret = true;
                    deploy = true;
                    owner = "root";
                    group = "root";
                    mode = privateKeyMode;
                  };
                  ${publicKeyFileName} = {
                    secret = false;
                    deploy = true;
                    owner = "root";
                    group = "root";
                    mode = publicKeyMode;
                  };
                };

                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.openssh
                ];

                script = ''
                  private_key="$out/${privateKeyFileName}"
                  temporary_public_key="$private_key.pub"
                  public_key="$out/${publicKeyFileName}"

                  ssh-keygen -q -t ed25519 -N "" -C "" -f "$private_key"
                  cut -d ' ' -f 1-2 "$temporary_public_key" > "$public_key"
                  rm "$temporary_public_key"
                  chmod ${privateKeyMode} "$private_key"
                  chmod ${publicKeyMode} "$public_key"
                '';
              };
            }
          ];
      };
  };
}
