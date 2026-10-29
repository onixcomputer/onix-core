# Machine-level NixOS modules for the OnixOS build (`extraNixosModules`).
#
# Each machine gets the same tag and machine files that Clan imports for it,
# plus the Clan base behaviour onix-core relies on (clan-carryover.nix) and a
# read-only bridge for the `clan.core.vars` paths those shared files still
# read (clan-vars-compat.nix). Services are not listed here: they are typed
# Nickel modules in onixos/services, assigned in onixos/inventory.ncl; only
# the upstream NixOS modules they configure come from their sidecars.
{
  self,
  inputs,
  lib,
}:
let
  definitions = self.lib.machines.definitions;
  sidecars = import ./service-sidecars.nix { inherit self inputs; };

  # Clan passes these as specialArgs (flake-outputs/clan.nix and clan-core's
  # machine module). OnixOS's nixosSystem call passes none, so nested modules
  # get them from `_module.args`.
  flakeArgs = {
    inherit inputs self;
    wrappers = inputs.wrappers.wrapperModules;
  };

  # nixos.nix, dev.nix and machine configuration.nix files use flakeArgs
  # inside `imports`, which `_module.args` cannot reach. Apply them to each
  # top-level file directly, keeping the file's other arguments.
  withFlakeArgs =
    file:
    let
      module = import file;
      requested = lib.functionArgs module;
      applied =
        if builtins.isFunction module then
          lib.setFunctionArgs (args: module (args // builtins.intersectAttrs requested flakeArgs)) (
            builtins.removeAttrs requested (builtins.attrNames flakeArgs)
          )
        else
          module;
    in
    {
      _file = file;
      key = toString file;
      imports = [ applied ];
    };

  # Clan applies inventory/tags/<tag>.nix through one importer instance per
  # tag file (inventory/tags/default.nix): base-settings for nixos.nix, which
  # every NixOS machine gets, and <tag>-tools for the others. Clan orders
  # those modules by instance name, and list-valued options merge in module
  # order, so the tag files follow the same order here.
  tagModules =
    name:
    let
      instanceName = tag: if tag == "nixos" then "base-settings" else "${tag}-tools";
      tags = lib.filter (tag: builtins.pathExists (../../inventory/tags + "/${tag}.nix")) (
        [ "nixos" ] ++ definitions.${name}.tags
      );
    in
    map (tag: withFlakeArgs (../../inventory/tags + "/${tag}.nix")) (
      lib.sort (a: b: instanceName a < instanceName b) tags
    );

  # A Clan service imports its upstream NixOS modules from its per-instance
  # module, a sibling of the tag files, so they load next to the tag files'
  # own imports. Two wrappers put the sidecars' modules at that depth, after
  # the tags.
  sidecarModules = {
    imports = [ { imports = sidecars.nixosModules; } ];
  };

  # clan-core's machine module auto-imports these when they exist, and loads
  # the facter report through the same string path.
  machineFiles =
    name:
    let
      facterJson = "${self}/machines/${name}/facter.json";
    in
    lib.optional (builtins.pathExists facterJson) { hardware.facter.reportPath = facterJson; }
    ++ map withFlakeArgs (
      lib.filter builtins.pathExists [
        (../../machines + "/${name}/configuration.nix")
        (../../machines + "/${name}/hardware-configuration.nix")
        (../../machines + "/${name}/disko.nix")
      ]
    );

  machineModules =
    name:
    [
      { _module.args = flakeArgs; }
      inputs.disko.nixosModules.disko
      (import ./clan-carryover.nix {
        inherit self;
        machineName = name;
      })
      ./clan-vars-compat.nix
    ]
    ++ machineFiles name
    ++ tagModules name
    ++ [ sidecarModules ];
in
lib.genAttrs [ "aspen2" ] machineModules
