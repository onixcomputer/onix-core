# iroh-ssh CLI tool (SSH config disabled for now)
{ inputs, pkgs, ... }:
let
  iroh-ssh = pkgs.callPackage "${inputs.self}/pkgs/iroh-ssh" { };
in
{
  home.packages = [ iroh-ssh ];
}
