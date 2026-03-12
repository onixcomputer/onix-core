{ lib, ... }:
let
  inherit (lib.types) attrsOf anything;
in
{
  _class = "clan.service";
  manifest = {
    name = "calibre-server";
    readme = "Calibre content server (OPDS/device sync) for a Calibre library";
  };

  roles = {
    server = {
      description = "Calibre content server";
      interface = {
        freeformType = attrsOf anything;
        options = { };
      };

      perInstance =
        { extendSettings, ... }:
        let
          baseSettings = extendSettings { };
          serverPort = baseSettings.port or 8080;
        in
        {
          exports.serviceEndpoints.calibre = {
            url = "http://localhost:${toString serverPort}";
            port = serverPort;
          };
          nixosModule =
            { lib, config, ... }:
            let
              settings = extendSettings { };
              libraries =
                settings.libraries
                  or (if settings ? libraryPath then [ settings.libraryPath ] else [ "/srv/calibre/library" ]);
              filteredSettings = builtins.removeAttrs settings [
                "libraryPath"
                "libraries"
              ];
            in
            {
              services.calibre-server = lib.mkMerge [
                {
                  enable = true;
                  inherit libraries;
                  openFirewall = true;
                }
                filteredSettings
              ];
              services.udisks2.enable = true;
              systemd.tmpfiles.rules = map (
                libraryPath:
                "d ${libraryPath} 0755 ${config.services.calibre-server.user} ${config.services.calibre-server.group} -"
              ) libraries;
            };
        };
    };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
