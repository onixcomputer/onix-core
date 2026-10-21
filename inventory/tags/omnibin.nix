# omnibin: every executable nixpkgs ever shipped, fetched from
# cache.nixos.org the first time a file in its store path is read.
#
# `omnibin` resolves names against the pinned index (`omnibin which`).
# `omnibin-shell` mounts the lazy store over /nix/store only inside a user and
# mount namespace that dies with the shell; the host store is served through it.
#
# The input's NixOS module is deliberately not imported. It mounts a read-only
# FUSE store over the host's /nix/store, so nix-daemon could no longer add
# paths (builds, deploys), and every binary on the machine would depend on that
# FUSE process staying alive.
{ pkgs, inputs, ... }:
let
  omnibin = inputs.omnibin.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  environment.systemPackages = [
    omnibin.omnibin
    omnibin.omnibin-shell
  ];
}
