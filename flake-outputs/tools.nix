# CLI tools, analysis utilities, and workflow helpers.
#
# Shared packages come from the onixpkgs overlay. The packages here depend on
# onix-core's own inputs, DGX inventory, or Nix fork.
{
  pkgs,
  lib,
  self,
  ...
}:
let
  sopsViz = (import ./_sops-viz.nix) { inherit pkgs; };

  dgxMachinePackage = pkgs.callPackage ../pkgs/dgx-machine {
    devenv = self.inputs.devenv-machines.packages.${pkgs.stdenv.hostPlatform.system}.devenv;
    machineInventory = ../inventory/dgx/generated/machines.json;
  };

  # nixpkgs marks radicle-node insecure: node traffic is cleartext and a peer
  # can claim another node's ID
  # (https://radicle.dev/2026/09/23/disclosure-of-vulnerability-in-network-protocol).
  # The fleet accepts that risk, private repositories included, until the
  # fixed major release. Naming the exact version fails evaluation again when
  # nixpkgs moves radicle-node. Machines receive this package through the
  # shared-nix overlay, so their own nixpkgs.config cannot exempt it.
  # r[impl onix.radicle_node.insecure_exemption]
  radicleNodePkgs = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.permittedInsecurePackages = [ "radicle-node-1.10.3" ];
  };

  wasmPackages = self.inputs.onix-wasm.packages.${pkgs.stdenv.hostPlatform.system};
  wasmHostImportFlags = old: {
    RUSTFLAGS = lib.concatStringsSep " " (
      lib.filter (flag: flag != "") [
        (old.RUSTFLAGS or "")
        "-Clink-arg=--allow-undefined"
      ]
    );
  };
  withWasmHostImports =
    package:
    package.overrideAttrs (
      old:
      wasmHostImportFlags old
      // {
        # Keep the dependency artifacts and the plugin on the same compiler flags.
        cargoArtifacts = old.cargoArtifacts.overrideAttrs wasmHostImportFlags;
      }
    );
  # The bundle only copies files. Apply linker flags before preinitialization.
  wasmPluginsWithHostImports = wasmPackages.wasm-plugins.override (previous: {
    plugins = wasmPackages.wasm-plugins-uninitialized.override {
      nickelPlugin = withWasmHostImports wasmPackages.nickel-plugin;
      yamlPlugin = withWasmHostImports wasmPackages.yaml-plugin;
      iniPlugin = withWasmHostImports wasmPackages.ini-plugin;
    };
    callPackage =
      file: args:
      (previous.callPackage file args).overrideAttrs (old: {
        # Wizer requires an equals sign for this optional Boolean argument.
        buildCommand =
          assert lib.assertMsg (lib.hasInfix "--keep-init-func false" old.buildCommand)
            "The Wizer compatibility override no longer matches the pinned preinitializer.";
          lib.replaceStrings [ "--keep-init-func false" ] [ "--keep-init-func=false" ] old.buildCommand;
      });
  });
in
{
  packages = {
    wasm-plugins = wasmPluginsWithHostImports;
    ki-editor = self.inputs.ki-editor.packages.${pkgs.stdenv.hostPlatform.system}.default;
    mercury-cli = self.inputs.mercury-cli.packages.${pkgs.stdenv.hostPlatform.system}.mercury-cli;
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    dgx-machine = dgxMachinePackage;
    inherit (radicleNodePkgs) radicle-node;
    inherit (pkgs) radicle-httpd;
  }
  // (sopsViz.packages or { });

  checks.pi-branchfs = pkgs.runCommand "pi-branchfs-tests" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
    node --test ${../modules/pi-branchfs}/tests.mjs
    touch "$out"
  '';

  apps = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    dgx-machine = {
      type = "app";
      program = lib.getExe dgxMachinePackage;
    };
  };
}
