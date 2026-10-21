{
  pkgs,
  lib,
  ...
}:
{
  imports = [ ../../shared/base/rbw.nix ];

  programs.rbw.settings = {
    email = lib.mkForce "b@robitzs.ch";
    base_url = lib.mkForce "https://vault.robitzs.ch";
    pinentry = lib.mkForce pkgs.rbw-pinentry;
  };
}
