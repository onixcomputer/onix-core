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
              settingsLib = import ./settings.nix { inherit lib; };
              validationErrors = settingsLib.validate settings;
              inherit (settings) libraries trustedIps;
              filteredSettings = builtins.removeAttrs settings [
                "libraries"
                "libraryPath"
                "trustedIps"
              ];
            in
            {
              assertions = [
                {
                  assertion = validationErrors == [ ];
                  message = lib.concatStringsSep "; " validationErrors;
                }
              ];

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

              # r[impl onix.bookshelf.calibre_write]
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
                    ++ lib.optional (trustedIps != [ ]) "--trusted-ips ${lib.concatStringsSep "," trustedIps}"
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
