{ pkgs }:
pkgs.writeShellApplication {
  name = "kiln-implementation-qualify";
  runtimeInputs = [
    pkgs.python3
    pkgs.b3sum
    pkgs.nix
    pkgs.nickel
    pkgs.e2fsprogs
    pkgs.util-linux
  ];
  text = ''
    exec ${pkgs.python3}/bin/python3 ${./qualification.py} "$@"
  '';
}
