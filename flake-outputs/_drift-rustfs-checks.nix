{ lib, pkgs, ... }:
{
  checks.drift-rustfs-policy =
    assert import ../modules/drift-rustfs/tests.nix { inherit lib; };
    pkgs.runCommand "drift-rustfs-policy" { } ''
      touch "$out"
    '';
}
