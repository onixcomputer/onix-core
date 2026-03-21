{ lib, ... }:
let
  inherit (lib) mkDefault;
  inherit (lib.types) attrsOf anything;
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
      interface = {
        freeformType = attrsOf anything;
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            _:
            let
              cfg = extendSettings {
                user = mkDefault "brittonr";
                group = mkDefault "users";
                dataDir = mkDefault "/home/brittonr";
                guiPort = mkDefault 8384;
                listenPort = mkDefault 22000;
                openFirewall = mkDefault true;
                guiAddress = mkDefault "127.0.0.1:8384";
              };
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

              # Syncthing Web UI — only on localhost by default
              # Access remotely via SSH tunnel: ssh -L 8384:localhost:8384 machine
            };
        };
    };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
