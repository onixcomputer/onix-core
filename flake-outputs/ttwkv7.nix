# Standalone ttWKV7 package, isolated so its missing upstream license does not
# relax unfree policy for the repository's general package set.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  isSupportedSystem = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  ttwkv7Pkgs = import self.inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfreePredicate = package: lib.getName package == "ttwkv7";
  };
  tenstorrentPackages = self.inputs.tenstorrent-nix.packages.${pkgs.stdenv.hostPlatform.system};
  rwkvLab = pkgs.callPackage ../pkgs/rwkv-lab { };
  rwkvLayerHarness = pkgs.callPackage ../pkgs/rwkv-layer-harness { };
  ttwkv7 = ttwkv7Pkgs.callPackage ../pkgs/ttwkv7 {
    inherit (tenstorrentPackages) enchantum tt-logger;
    inherit (tenstorrentPackages) tt-metal;
  };
in
{
  packages = lib.optionalAttrs isSupportedSystem {
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.session_receipts]
    rwkv-lab = rwkvLab;
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.real_weight_layer]
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.greedy_token]
    rwkv-layer-harness = rwkvLayerHarness;
    # r[impl onix.tenstorrent.native_runtime.ttwkv7.package]
    inherit ttwkv7;
  };

  checks = lib.optionalAttrs isSupportedSystem {
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]
    ttwkv7-architectures = ttwkv7.passthru.architectureCheck;
  };
}
