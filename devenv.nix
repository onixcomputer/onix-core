{ inputs, lib, ... }:
let
  inventory = builtins.fromJSON (builtins.readFile ./inventory/dgx/generated/machines.json);
  clanMachineNames = builtins.fromJSON (
    builtins.readFile ./inventory/dgx/generated/clan-machine-names.json
  );
  machines = import ./devenv/dgx-machines.nix {
    inherit
      inputs
      inventory
      lib
      ;
    inherit clanMachineNames;
    projectRoot = ./.;
  };
in
{
  inherit machines;
}
