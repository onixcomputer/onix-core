{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "syncthing";
    readme = "Continuous file synchronization across devices via Syncthing";
  };

  roles = {
    peer = {
      description = "Syncthing peer that syncs folders with other peers";
      interface = mkSettings.mkInterface schema.peer;

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { lib, ... }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              cfg = extendSettings (ms.mkDefaults schema.peer);
            in
            {
              services.syncthing = {
                enable = true;
                inherit (cfg) user group dataDir;
                inherit (cfg) guiAddress;
                openDefaultPorts = cfg.openFirewall;
                overrideDevices = false;
                overrideFolders = false;
              };

              # Syncthing discovery and relay ports
              networking.firewall = lib.mkIf cfg.openFirewall {
                allowedTCPPorts = [ cfg.listenPort ];
                allowedUDPPorts = [
                  cfg.listenPort
                  21027 # discovery
                ];
              };
            };
        };
    };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
