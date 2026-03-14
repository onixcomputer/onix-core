# Clan-core configuration: machines, inventory, and modules.
#
# Called directly from flake.nix (not an adios-flake module) because
# nixosConfigurations, darwinConfigurations, clan, and clanInternals
# are flake-level outputs that bypass per-system evaluation.
{ self, inputs }:
let
  modules = import "${self}/modules/default.nix" { inherit inputs; };

  clanModule = inputs.clan-core.lib.clan {
    inherit self;
    meta.name = "Onix";
    inherit modules;
    inventory = import "${self}/inventory" { inherit inputs; };
    specialArgs = {
      inherit inputs;
      wrappers = inputs.wrappers.wrapperModules;
    };
  };
in
{
  inherit (clanModule.config)
    nixosConfigurations
    darwinConfigurations
    clanInternals
    ;
  clan = clanModule.config;

  lib = {
    machines = {
      names = builtins.attrNames (import ../inventory/core/machines.nix { });
      hasTag =
        machine: tag:
        let
          machinesDef = import ../inventory/core/machines.nix { };
        in
        builtins.elem tag (machinesDef.${machine}.tags or [ ]);
    };
    tags = {
      all =
        let
          tagDir = ../inventory/tags;
          contents = builtins.readDir tagDir;
          nixFiles = builtins.filter (name: builtins.match ".*\\.nix" name != null && name != "default.nix") (
            builtins.attrNames contents
          );
        in
        map (name: builtins.replaceStrings [ ".nix" ] [ "" ] name) nixFiles;
    };
    users.names = [ "brittonr" ];
    inherit inputs;
  };
}
