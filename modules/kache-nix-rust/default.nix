{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  cacheDirectoryMode = "1777";
in
{
  _class = "clan.service";

  manifest = {
    name = "kache-nix-rust";
    readme = "Opt-in Nix-owned kache integration for sandboxed Rust builds";
    description = "Creates a machine-owned kache cache path and exposes it narrowly to opted-in Nix Rust builders";
    categories = [
      "Development"
      "Builds"
    ];
  };

  roles.default = {
    description = "Machine with opt-in Nix Rust kache pilot support";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { extendSettings, ... }:
      {
        nixosModule =
          { lib, ... }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            cfg = extendSettings (ms.mkDefaults schema.default);
          in
          {
            config = lib.mkIf cfg.enable {
              assertions = [
                {
                  assertion = cfg.cacheDir != "/home/brittonr/.cache/kache";
                  message = "kache-nix-rust cacheDir must be machine-owned, not /home/brittonr/.cache/kache";
                }
                {
                  assertion = cfg.cacheDir != "";
                  message = "kache-nix-rust cacheDir must not be empty";
                }
              ];

              systemd.tmpfiles.rules = [
                "d ${cfg.cacheDir} ${cacheDirectoryMode} root root -"
              ];

              nix.settings.extra-sandbox-paths = lib.mkIf cfg.exposeSandboxPath [
                cfg.cacheDir
              ];
            };
          };
      };
  };
}
