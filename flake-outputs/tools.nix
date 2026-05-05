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
    nix-eval-warnings = pkgs.callPackage ../pkgs/nix-eval-warnings { };
    claude-md = pkgs.python3.pkgs.callPackage ../pkgs/claude-md { };
    hx-oil = pkgs.callPackage ../pkgs/hx-oil { };
    tuicr = pkgs.callPackage ../pkgs/tuicr { };
    updater = pkgs.callPackage ../pkgs/updater { };
    inherit buildbot-pr-check;
    merge-when-green = pkgs.callPackage ../pkgs/merge-when-green { inherit buildbot-pr-check; };
    dumbpipe = pkgs.callPackage ../pkgs/dumbpipe { };
    sendme = pkgs.callPackage ../pkgs/sendme { };
    crw = pkgs.callPackage ../pkgs/crw { };
    verify-deploy = pkgs.callPackage ../pkgs/verify-deploy { };
    ki-editor = self.inputs.ki-editor.packages.${pkgs.stdenv.hostPlatform.system}.default;
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    branchfs = pkgs.callPackage ../pkgs/branchfs { };
    horizon = pkgs.callPackage ../pkgs/horizon { horizon-src = self.inputs.horizon; };
    llamacpp-rocm-rpc = pkgs.callPackage ../pkgs/llamacpp-rocm-rpc { };
    lemonade-server = pkgs.callPackage ../pkgs/lemonade { };
  }
  // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    sone = pkgs.callPackage ../pkgs/sone { };
    opendeck = pkgs.callPackage ../pkgs/opendeck { };
    open-notebook = pkgs.callPackage ../pkgs/open-notebook { };
  }
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
