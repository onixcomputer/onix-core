# Build the CLI-oriented system profile from the exact evaluated NixOS package
# list for aspen2. The host package index publishes this derivation as
# `system-tools`; host-tools.ncl adds that profile to the native host.
#
# NixOS's config.environment.systemPackages is the configured source: the
# pinned system-path.nix composes corePackages, defaultPackages and all module
# contributions (including configured package outputs). Do not consume
# cfg.system.path: it is the NixOS system profile, with NixOS-specific
# post-build setup and manager commands that are not part of this host.
{
  lib,
  pkgs,
  cfg,
}:
let
  policy = import ./package-policy.nix { inherit lib; };
  retainedSystemPackages = policy.keepPackages cfg.environment.systemPackages;
in
pkgs.buildEnv {
  name = "onixos-aspen2-system-tools";
  paths = retainedSystemPackages;

  # Retain the configured host paths plus the metadata needed for interactive
  # tools. In particular this links package man pages and fish/bash completions
  # without flattening cfg.system.path into the target.
  pathsToLink = lib.unique (
    cfg.environment.pathsToLink
    ++ [
      "/bin"
      "/sbin"
      "/share/man"
      "/share/fish"
      "/share/bash-completion"
      "/share/terminfo"
    ]
  );
  extraOutputsToInstall = cfg.environment.extraOutputsToInstall;
  ignoreCollisions = true;
}
