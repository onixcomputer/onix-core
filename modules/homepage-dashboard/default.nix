{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "homepage-dashboard";
    readme = "Homepage dashboard service for customizable web portal and service links";
  };

  roles = {
    server = {
      description = "Homepage dashboard server that provides a customizable web portal";
      interface = mkSettings.mkInterface schema.server;

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { lib, ... }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              mergedSettings = extendSettings (ms.mkDefaults schema.server);
            in
            {
              services.homepage-dashboard = mergedSettings;
            };
        };
    };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
