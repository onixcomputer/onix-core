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
        {
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

              # Quote paths for tmpfiles — spaces in directory names break
              # the space-delimited format without quotes.
              systemd.tmpfiles.rules = map (
                libraryPath:
                "d '${libraryPath}' 0755 ${config.services.calibre-server.user} ${config.services.calibre-server.group} -"
              ) libraries;

              # The upstream NixOS calibre-server module joins library paths
              # with spaces and doesn't quote them, so paths containing
              # spaces get word-split.  Override ExecStart with properly
              # escaped arguments.
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
