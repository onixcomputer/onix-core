{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "hister";
    readme = "Hister self-hosted web history search server";
  };

  roles = {
    server = {
      description = "Hister search server";
      interface = mkSettings.mkInterface schema.server;

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { lib, ... }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              settings = extendSettings (ms.mkDefaults schema.server);
            in
            {
              services.hister = {
                enable = true;
                inherit (settings) openFirewall;
                inherit (settings) port;
                dataDir = lib.mkIf (settings.dataDir != null) settings.dataDir;
                settings.server.address = "${settings.bindAddress}:${toString settings.port}";
              };
            };
        };
    };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
