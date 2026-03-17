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
    inventory = import "${self}/inventory" { inherit inputs self; };
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
    # Wasm plugin library — call with a system string to get evalNickelFile, fromYAML, etc.
    # Usage: self.lib.wasm "x86_64-linux" → { evalNickelFile, evalNickel, fromYAML, toYAML, fromINI }
    wasm =
      system:
      import ../lib/wasm.nix {
        plugins = self.packages.${system}.wasm-plugins;
      };

    machines =
      let
        wasmLib = import ../lib/wasm.nix {
          plugins = self.packages.x86_64-linux.wasm-plugins;
        };
        machinesDef = (wasmLib.evalNickelFile ../inventory/core/machines.ncl).machines;
      in
      {
        names = builtins.attrNames machinesDef;
        hasTag = machine: tag: builtins.elem tag (machinesDef.${machine}.tags or [ ]);
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
