# OnixOS consumer checks: the typed Nickel services' inline tests plus the
# inventory contract (onixos/tests.ncl), and a build of every machine
# OnixOS assembles (flake-outputs/onixos.nix).
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  runner = pkgs.writeText "onixos-tests.ncl" ''
    let onix = import "${self.inputs.onix-modules}/lib/onix.ncl" in
    (import "${self}/onixos/tests.ncl") onix
  '';
  machines = lib.filterAttrs (
    name: _machine: self.lib.machines.definitions.${name}.system == system
  ) self.onixos.nixosConfigurations;
in
{
  checks = {
    onixos-services = pkgs.runCommand "onixos-services" { nativeBuildInputs = [ pkgs.nickel ]; } ''
      nickel export --format json ${runner} > $out
    '';
  }
  // lib.mapAttrs' (
    name: machine: lib.nameValuePair "onixos-${name}" machine.config.system.build.toplevel
  ) machines;
}
