{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "tailscale";
    description = "Tailscale VPN - Zero-config mesh networking";
    readme = "Tailscale mesh VPN service for secure peer-to-peer networking";
    categories = [
      "Networking"
      "VPN"
    ];
  };

  roles.peer = {
    description = "Tailscale peer that connects to the mesh VPN network";
    interface = mkSettings.mkInterface schema.peer;

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
            settings = extendSettings (ms.mkDefaults schema.peer);
            generatorName = "tailscale-${instanceName}";
            authKeyFile = config.clan.core.vars.generators.${generatorName}.files.auth_key.path;
            serviceConfig = import ./mk-nixos-config.nix {
              inherit
                authKeyFile
                config
                lib
                pkgs
                settings
                ;
            };
          in
          {
            imports = [ ./host-sync.nix ];

            config = lib.mkMerge [
              serviceConfig
              {
                clan.core.vars.generators.${generatorName} = {
                  share = true;
                  files.auth_key = { };
                  runtimeInputs = [ pkgs.coreutils ];

                  prompts.auth_key = {
                    description = "Tailscale auth key for instance '${instanceName}'";
                    type = "hidden";
                    persist = true;
                  };

                  script = ''
                    cat "$prompts"/auth_key > "$out"/auth_key
                  '';
                };
              }
            ];
          };
      };
  };
}
