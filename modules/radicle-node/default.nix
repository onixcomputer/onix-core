# r[impl onix.radicle_node.hosting]
{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  validateSettings = import ./validate-settings.nix { inherit lib; };
  mkNixosConfig = import ./mk-nixos-config.nix { inherit lib; };
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
            }
          ];
      };
  };
}
