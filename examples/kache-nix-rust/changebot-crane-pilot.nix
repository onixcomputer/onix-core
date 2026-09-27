# Wrap a changebot/remora Crane package with the Nix-owned kache rustc wrapper.
#
# The caller supplies `changebotPackage`, usually from ../changebot, and the
# kache wrapper library from onixpkgs:
#
#   let
#     onixpkgs = builtins.getFlake "git+ssh://git@github.com/OnixResearch/onixpkgs.git";
#     changebot = builtins.getFlake "path:/home/brittonr/git/changebot";
#     system = builtins.currentSystem;
#     pkgs = import onixpkgs.inputs.nixpkgs { inherit system; };
#   in
#   import /home/brittonr/git/onix-core/examples/kache-nix-rust/changebot-crane-pilot.nix {
#     inherit pkgs;
#     inherit (onixpkgs.lib) kacheNixRust;
#     onixPackages = onixpkgs.packages.${system};
#     changebotPackage = changebot.packages.${system}.default;
#   }
{
  pkgs,
  lib ? pkgs.lib,
  kacheNixRust,
  onixPackages,
  changebotPackage,
  enableKache ? true,
  cacheDir ? "/var/cache/kache-nix",
  keySalt ? "changebot-crane-pilot-v1",
}:
let
  kacheLib = kacheNixRust {
    inherit lib pkgs;
    kachePackage = onixPackages.kache;
  };

  rustcWrapper = kacheLib.mkCargoRustcWrapper {
    name = "changebot-kache-rustc-wrapper";
    inherit cacheDir keySalt;
  };
in
if enableKache then
  changebotPackage.overrideAttrs (_oldAttrs: {
    RUSTC_WRAPPER = lib.getExe rustcWrapper;
    KACHE_NIX_CACHE_DIR = cacheDir;
  })
else
  changebotPackage
