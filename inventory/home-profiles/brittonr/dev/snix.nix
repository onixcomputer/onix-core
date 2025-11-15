{ inputs, pkgs, ... }:
let
  # Import the snix depot with the required arguments
  snix = import inputs.snix {
    localSystem = pkgs.system;
    nixpkgsConfig = {};
  };

  # Create wrapper packages for snix commands with proper names
  snix-cli = pkgs.runCommand "snix-cli" {
    buildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p $out/bin
    ln -s ${snix.snix.cli}/bin/snix $out/bin/snix-cli
    ln -s ${snix.snix.cli}/bin/snix $out/bin/snix
  '';

  # Additional binary wrappers for other Snix components
  snix-store = pkgs.runCommand "snix-store" {
    buildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p $out/bin
    ln -s ${snix.snix.store}/bin/snix-store $out/bin/snix-store
  '';

  snix-build = pkgs.runCommand "snix-build" {
    buildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p $out/bin
    if [ -e ${snix.snix.build}/bin/snix-build ]; then
      ln -s ${snix.snix.build}/bin/snix-build $out/bin/snix-build
    else
      touch $out/bin/.placeholder
    fi
  '';

  snix-castore = pkgs.runCommand "snix-castore" {
    buildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p $out/bin
    if [ -e ${snix.snix.castore}/bin/snix-castore ]; then
      ln -s ${snix.snix.castore}/bin/snix-castore $out/bin/snix-castore
    else
      touch $out/bin/.placeholder
    fi
  '';

  nar-bridge = let
    narBridgePkg = snix.snix.nar-bridge or (snix.snix."nar-bridge" or null);
  in if narBridgePkg != null then
    pkgs.runCommand "nar-bridge" {
      buildInputs = [ pkgs.makeWrapper ];
    } ''
      mkdir -p $out/bin
      ln -s ${narBridgePkg}/bin/nar-bridge $out/bin/nar-bridge
    ''
  else null;

  # Filter function to check if something is a package
  isPackage = x:
    x != null &&
    (builtins.isAttrs x) &&
    (x ? outPath || x ? type && x.type == "derivation");

  # Snix boot VM runner - for running VMs with Nix store access via virtiofs
  # Usage:
  #   snix-boot-vm                    # Interactive shell in VM
  #   CH_CMDLINE="..." snix-boot-vm  # Run with custom kernel cmdline
  #   CH_NUM_CPUS=4 CH_MEM_SIZE=2G snix-boot-vm  # Customize VM resources
  snix-boot-vm = if (snix.snix ? boot && snix.snix.boot ? runVM) then
    pkgs.runCommand "snix-boot-vm" {
      buildInputs = [ pkgs.makeWrapper ];
    } ''
      mkdir -p $out/bin
      ln -s ${snix.snix.boot.runVM}/bin/run-snix-vm $out/bin/snix-boot-vm
      ln -s ${snix.snix.boot.runVM}/bin/run-snix-vm $out/bin/run-snix-vm
    ''
  else null;

  # Collect optional packages, filtering out non-packages
  optionalPackages = builtins.filter isPackage [
    # Additional depot tools
    (snix.tools.crfo-approve or null)
    (snix.tools.gerrit-update or null)

    # Additional snix components
    (snix.snix.eval or null)
    (snix.snix.glue or null)

    # Snix boot VM runner
    snix-boot-vm
  ];
in
{
  home.packages = [
    # Main Snix CLI - experimental Nix implementation in Rust
    snix-cli

    # Snix store implementation
    snix-store

    # Snix build system
    snix-build

    # Content-addressed storage
    snix-castore

    # NAR bridge
    nar-bridge

    # Depot development tools
    snix.tools.depotfmt
    snix.tools.gerrit-cli
    snix.tools.magrathea

    # Dependencies for snix-boot-vm
    pkgs.cloud-hypervisor  # VM hypervisor required by snix boot
    pkgs.virtiofsd         # virtiofs daemon for /nix/store sharing
  ] ++ optionalPackages;
}