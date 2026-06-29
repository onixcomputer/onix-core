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
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            cfg = extendSettings (ms.mkDefaults schema.default);
            zfsBin = "${config.boot.zfs.package}/bin/zfs";
            findmntBin = "${pkgs.util-linux}/bin/findmnt";
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
                {
                  assertion = cfg.zfsDataset == null || cfg.zfsDataset != "";
                  message = "kache-nix-rust zfsDataset must be null or a non-empty dataset name";
                }
              ];

              system.activationScripts.kache-nix-rust-cache-zfs-dataset = lib.mkIf (cfg.zfsDataset != null) ''
                dataset=${lib.escapeShellArg cfg.zfsDataset}
                mountpoint=${lib.escapeShellArg cfg.cacheDir}
                zfs=${lib.escapeShellArg zfsBin}
                findmnt=${lib.escapeShellArg findmntBin}

                mkdir -p "$(dirname "$mountpoint")"

                if ! "$zfs" list -H -o name "$dataset" >/dev/null 2>&1; then
                  "$zfs" create -o mountpoint="$mountpoint" "$dataset"
                else
                  "$zfs" set mountpoint="$mountpoint" "$dataset"
                fi

                "$zfs" mount "$dataset" >/dev/null 2>&1 || true

                actual_source="$("$findmnt" -no SOURCE --target "$mountpoint" 2>/dev/null || true)"
                if [ "$actual_source" != "$dataset" ]; then
                  echo "kache-nix-rust: $mountpoint is not mounted from $dataset after activation" >&2
                  exit 1
                fi

                chmod ${cacheDirectoryMode} "$mountpoint"
              '';

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
