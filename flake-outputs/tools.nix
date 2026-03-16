# CLI tools, analysis utilities, and workflow helpers.
#
# Inline package definitions (formerly in parts/) plus sops-viz import.
{
  pkgs,
  lib,
  ...
}:
let
  sopsViz = (import ./_sops-viz.nix) { inherit pkgs; };

  buildbot-pr-check = pkgs.callPackage ../pkgs/buildbot-pr-check { };
in
{
  packages = {
    wasm-plugins = pkgs.callPackage ../wasm-plugins { inherit (pkgs.llvmPackages) lld; };
    ccusage = pkgs.callPackage ../pkgs/ccusage { };
    nix-eval-warnings = pkgs.callPackage ../pkgs/nix-eval-warnings { };
    iroh-ssh = pkgs.callPackage ../pkgs/iroh-ssh { };
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
  }
  // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    abp = pkgs.callPackage ../pkgs/abp { };
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
