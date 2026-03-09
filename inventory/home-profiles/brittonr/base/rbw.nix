{ pkgs, lib, ... }:
let
  rbw-pinentry = pkgs.callPackage ../../../../pkgs/rbw-pinentry { };
in
{
  imports = [ ../../shared/base/rbw.nix ];

  programs.rbw.settings = {
    email = lib.mkForce "b@robitzs.ch";
    base_url = lib.mkForce "https://vault.robitzs.ch";
    pinentry = lib.mkForce rbw-pinentry;
  };
}
