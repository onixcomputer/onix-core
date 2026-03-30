{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "harmonia";
    readme = "Nix binary cache server (harmonia) that serves the local nix store over HTTP";
  };

  roles = {
    server = {
      description = "Harmonia binary cache server";
      interface = mkSettings.mkInterface schema.server;

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, lib, ... }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              cfg = extendSettings (ms.mkDefaults schema.server);
            in
            {
              services.harmonia.cache = {
                enable = true;
                signKeyPaths = [
                  config.clan.core.vars.generators.nix-signing-key.files."key".path
                ];
                settings = {
                  bind = "[::]:${toString cfg.port}";
                  inherit (cfg) workers;
                  max_connection_rate = cfg.maxConnectionRate;
                  inherit (cfg) priority;
                };
              };

              networking.firewall.allowedTCPPorts = [ cfg.port ];
            };
        };
    };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
