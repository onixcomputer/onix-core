{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
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
      interface = mkSettings.mkInterface schema.server;

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { lib, config, ... }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              settings = extendSettings (ms.mkDefaults schema.server);
              inherit (settings) libraries;
              filteredSettings = builtins.removeAttrs settings [
                "libraries"
                "libraryPath"
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
                "d '${libraryPath}' 0755 ${config.services.calibre-server.user} ${config.services.calibre-server.group} -"
              ) libraries;

              systemd.services.calibre-server.serviceConfig.ExecStart =
                let
                  pkg = config.services.calibre-server.package;
                  libraryArgs = lib.concatMapStringsSep " " lib.escapeShellArg libraries;
                in
                lib.mkForce "${pkg}/bin/calibre-server ${libraryArgs} ${
                  lib.concatStringsSep " " (
                    lib.mapAttrsToList (k: v: "${k} ${toString v}") (
                      lib.filterAttrs (_: v: v != null) {
                        "--listen-on" = config.services.calibre-server.host;
                        "--port" = config.services.calibre-server.port;
                        "--auth-mode" = config.services.calibre-server.auth.mode;
                        "--userdb" = config.services.calibre-server.auth.userDb;
                      }
                    )
                    ++ [ (lib.optionalString config.services.calibre-server.auth.enable "--enable-auth") ]
                    ++ config.services.calibre-server.extraFlags
                  )
                }";
            };
        };
    };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
