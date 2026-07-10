# Tenstorrent Blackhole host support.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  tenstorrentPackages = inputs.tenstorrent-nix.packages.${pkgs.stdenv.hostPlatform.system};

  # Build the KMD against the selected host kernel, not the upstream flake's
  # default linux package.  britton-desktop pins boot.kernelPackages, so the
  # out-of-tree module must follow that exact kernel package set.
  tenstorrentKernelModule = config.boot.kernelPackages.callPackage (
    inputs.tenstorrent-nix + "/pkgs/kmd"
  ) { };

  tenstorrentKernelModuleName = "tenstorrent";
  tenstorrentToolPackageNames = [
    "burnin"
    "flash"
    "luwen"
    "pyluwen"
    "smi"
    "system-tools"
    "topology"
  ];

  selectTenstorrentTools = packages: lib.attrVals tenstorrentToolPackageNames packages;
in
{
  boot = {
    extraModulePackages = [ tenstorrentKernelModule ];
    kernelModules = [ tenstorrentKernelModuleName ];
  };

  services.udev.packages = [ tenstorrentKernelModule ];

  environment.systemPackages = selectTenstorrentTools tenstorrentPackages;
}
