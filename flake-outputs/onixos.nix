# OnixOS consumer build.
#
# Assembles machines from onixos/inventory.ncl with the onix-modules mkFlake
# (Nix backend) instead of Clan. Every NixOS machine is declared there, but
# only the machines with machine modules in onixos/nix/machines.nix are
# assembled and exposed, as `onixos.nixosConfigurations.<machine>`;
# `onixos/tools/parity` diffs a machine's two builds from the same source.
#
# A cut-over machine's `nixosConfigurations` entry is its OnixOS build, which
# `onix deploy` (and `clan machines update`) then deploy. Clan's build stays at
# `clan.nixosConfigurations.<machine>` for parity and rollback. Every other
# machine keeps Clan's build.
#
# Called directly from flake.nix, like clan.nix: these are flake-level outputs.
{ self, inputs }:
let
  system = "x86_64-linux";
  inherit (inputs.nixpkgs) lib;

  onix = inputs.onix-modules.lib.${system};

  # Every onixos/services/<name>.ncl file is a typed Nickel service module
  # named <name>; its sidecar may name modules it must follow. `onix check`
  # resolves services from the same directory.
  serviceDir = ../onixos/services;
  sidecars = import ../onixos/nix/service-sidecars.nix { inherit self inputs; };
  modules =
    lib.mapAttrs'
      (
        file: _type:
        let
          name = lib.removeSuffix ".ncl" file;
        in
        lib.nameValuePair name (
          {
            file = serviceDir + "/${file}";
          }
          // lib.optionalAttrs (sidecars.moduleInputs.${name} or [ ] != [ ]) {
            inputs = sidecars.moduleInputs.${name};
          }
        )
      )
      (
        lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".ncl" file) (
          builtins.readDir serviceDir
        )
      );

  machineModules = import ../onixos/nix/machines.nix { inherit self inputs lib; };

  onixOutputs = onix.mkFlake {
    inputs = {
      inherit self;
      inherit (inputs)
        nixpkgs
        sops-nix
        disko
        nixos-artifacts
        ;
    };
    inventoryFile = ../onixos/inventory.ncl;
    inherit modules;
    extraNixosModules = machineModules;
    overlays = import ../onixos/nix/package-overlays.nix { inherit self inputs; };
  };

  assembled = lib.getAttrs (lib.attrNames machineModules) onixOutputs.nixosConfigurations;

  # Machines deployed from their OnixOS build (docs/onixos-aspen2-pilot.md).
  cutOverMachines = [ "aspen2" ];
in
{
  nixosConfigurations = self.clan.nixosConfigurations // lib.getAttrs cutOverMachines assembled;

  onixos = {
    nixosConfigurations = assembled;
    inherit (onixOutputs) _onix;
  };
}
