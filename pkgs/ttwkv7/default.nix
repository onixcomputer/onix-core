{
  callPackage,
  enchantum,
  tt-logger,
  tt-metal,
}:
let
  source = callPackage ./source.nix { };
  binaries = callPackage ./binaries.nix {
    inherit
      enchantum
      source
      tt-logger
      tt-metal
      ;
  };
  kernels = callPackage ./kernels.nix { inherit source; };
  architectureCheck = callPackage ./architecture-check.nix {
    inherit kernels source tt-metal;
  };
in
# r[impl onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]
callPackage ./runtime.nix {
  inherit
    architectureCheck
    binaries
    kernels
    source
    tt-metal
    ;
}
