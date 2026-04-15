# CLI tools, analysis utilities, and workflow helpers.
#
# Inline package definitions (formerly in parts/) plus sops-viz import.
{
  pkgs,
  lib,
  self,
  ...
}:
let
  sopsViz = (import ./_sops-viz.nix) { inherit pkgs; };

  buildbot-pr-check = pkgs.callPackage ../pkgs/buildbot-pr-check { };
in
{
  packages = {
    inherit (self.inputs.onix-wasm.packages.${pkgs.stdenv.hostPlatform.system}) wasm-plugins;
    ccusage = pkgs.callPackage ../pkgs/ccusage { };
    nix-eval-warnings = pkgs.callPackage ../pkgs/nix-eval-warnings { };
    claude-md = pkgs.python3.pkgs.callPackage ../pkgs/claude-md { };
    tuicr = pkgs.callPackage ../pkgs/tuicr { };
    updater = pkgs.callPackage ../pkgs/updater { };
    inherit buildbot-pr-check;
    merge-when-green = pkgs.callPackage ../pkgs/merge-when-green { inherit buildbot-pr-check; };
    dumbpipe = pkgs.callPackage ../pkgs/dumbpipe { };
    sendme = pkgs.callPackage ../pkgs/sendme { };
    verify-deploy = pkgs.callPackage ../pkgs/verify-deploy { };
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    branchfs = pkgs.callPackage ../pkgs/branchfs { };
    horizon = pkgs.callPackage ../pkgs/horizon { horizon-src = self.inputs.horizon; };
    llamacpp-rocm-rpc = pkgs.callPackage ../pkgs/llamacpp-rocm-rpc { };
    lemonade-server = pkgs.callPackage ../pkgs/lemonade { };
    inherit (self.inputs.clankers.packages.${pkgs.stdenv.hostPlatform.system}) clanker-router;
  }
  // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (
    let
      rustPkgs = import self.inputs.nixpkgs {
        inherit (pkgs) system;
        overlays = [ (import self.inputs.rust-overlay) ];
      };
      nightlyToolchain = rustPkgs.rust-bin.nightly.latest.default.override {
        extensions = [ "rust-src" ];
      };
    in
    {
      abp = pkgs.callPackage ../pkgs/abp { };
      sone = pkgs.callPackage ../pkgs/sone { };
      opendeck = pkgs.callPackage ../pkgs/opendeck { };
      open-notebook = pkgs.callPackage ../pkgs/open-notebook { };
      clankers = pkgs.callPackage ../pkgs/clankers {
        rustc = nightlyToolchain;
        cargo = nightlyToolchain;
      };
    }
  )
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    rbw-pinentry = pkgs.callPackage ../pkgs/rbw-pinentry { };
  }
  // (
    let
      traceyPkg = pkgs.callPackage ../pkgs/tracey { };
    in
    lib.optionalAttrs (builtins.elem pkgs.stdenv.hostPlatform.system (
      traceyPkg.meta.platforms or [ ]
    )) { tracey = traceyPkg; }
  )
  // (sopsViz.packages or { });
}
