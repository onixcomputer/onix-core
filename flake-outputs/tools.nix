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
  ghzingaPackage = pkgs.callPackage ../pkgs/ghzinga { };
  herdrPackage = pkgs.callPackage ../pkgs/herdr {
    ghzinga = ghzingaPackage;
    herdr = self.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
    wrapperLib = self.inputs.wrappers.lib;
  };
  dgxMachinePackage = pkgs.callPackage ../pkgs/dgx-machine {
    devenv = self.inputs.devenv-machines.packages.${pkgs.stdenv.hostPlatform.system}.devenv;
    machineInventory = ../inventory/dgx/generated/machines.json;
  };

  wasmPluginsWithHostImports =
    self.inputs.onix-wasm.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins.overrideAttrs
      (old: {
        RUSTFLAGS = lib.concatStringsSep " " (
          lib.filter (flag: flag != "") [
            (old.RUSTFLAGS or "")
            "-Clink-arg=--allow-undefined"
          ]
        );
      });
in
{
  packages = {
    wasm-plugins = wasmPluginsWithHostImports;
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
    ghzinga = ghzingaPackage;
    kache = pkgs.callPackage ../pkgs/kache { };
    verify-deploy = pkgs.callPackage ../pkgs/verify-deploy { };
    ki-editor = self.inputs.ki-editor.packages.${pkgs.stdenv.hostPlatform.system}.default;
    mercury-cli = self.inputs.mercury-cli.packages.${pkgs.stdenv.hostPlatform.system}.mercury-cli;
    prime-agent = pkgs.callPackage ../pkgs/prime-agent { };
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    branchfs = pkgs.callPackage ../pkgs/branchfs { };
    celld = pkgs.callPackage ../pkgs/celld { };
    herdr = herdrPackage;
    horizon = pkgs.callPackage ../pkgs/horizon { horizon-src = self.inputs.horizon; };
    iroh-ssh = pkgs.callPackage ../pkgs/iroh-ssh { };
    dgx-machine = dgxMachinePackage;
    llamacpp-rocm-rpc = pkgs.callPackage ../pkgs/llamacpp-rocm-rpc { };
    llamacpp-rocm-dspark = pkgs.callPackage ../pkgs/llamacpp-rocm-dspark { };
    deepseek-v4-dspark-draft = pkgs.callPackage ../pkgs/deepseek-v4-dspark-draft { };
    lemonade-server = pkgs.callPackage ../pkgs/lemonade { };
    mesh-llm = pkgs.callPackage ../pkgs/mesh-llm { };
    radicle-ci-runner = pkgs.callPackage ../pkgs/radicle-ci-runner { };
    inherit (pkgs) radicle-node;
    inherit (pkgs) radicle-httpd;
  }
  // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    sone = pkgs.callPackage ../pkgs/sone { };
    opendeck = pkgs.callPackage ../pkgs/opendeck { };
    open-notebook = pkgs.callPackage ../pkgs/open-notebook { };
    openbubbles = pkgs.callPackage ../pkgs/openbubbles { };
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
  // (
    let
      kunaPkg = pkgs.callPackage ../pkgs/kuna { };
    in
    lib.optionalAttrs (builtins.elem pkgs.stdenv.hostPlatform.system (kunaPkg.meta.platforms or [ ])) {
      kuna = kunaPkg;
    }
  )
  // (sopsViz.packages or { });

  apps = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    dgx-machine = {
      type = "app";
      program = lib.getExe dgxMachinePackage;
    };
  };
}
