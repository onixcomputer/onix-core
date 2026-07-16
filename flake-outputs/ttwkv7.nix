# Standalone ttWKV7 package, isolated so its missing upstream license does not
# relax unfree policy for the repository's general package set.
{
  self,
  pkgs,
  lib,
  ...
}:
{
  packages = lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (
    let
      ttwkv7Pkgs = import self.inputs.nixpkgs {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfreePredicate = package: lib.getName package == "ttwkv7";
      };
      tenstorrentPackages = self.inputs.tenstorrent-nix.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      # r[impl onix.tenstorrent.native_runtime.ttwkv7.package]
      ttwkv7 = ttwkv7Pkgs.callPackage ../pkgs/ttwkv7 {
        inherit (tenstorrentPackages) enchantum tt-logger;
        inherit (tenstorrentPackages) tt-metal;
      };
    }
  );
}
