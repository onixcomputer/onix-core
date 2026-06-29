# kache-nix-rust settings schema — Nix-owned Rust build cache pilot.
{
  default = {
    enable = {
      type = "bool",
      default = false,
      description = "Enable the Nix-owned kache Rust build cache pilot on this machine",
    },
    cacheDir = {
      type = "string",
      default = "/var/cache/kache-nix",
      description = "Machine-owned kache cache directory exposed to opted-in Nix builders",
    },
    exposeSandboxPath = {
      type = "bool",
      default = true,
      description = "Expose cacheDir through nix.settings.extra-sandbox-paths when the pilot is enabled",
    },
    zfsDataset = {
      type = "nullable_string",
      default = null,
      description = "Optional ZFS dataset to create and mount at cacheDir during activation",
    },
    keySalt = {
      type = "string",
      default = "",
      description = "Operator-provided salt appended to wrapper-derived Rust toolchain identity",
    },
  },
}
