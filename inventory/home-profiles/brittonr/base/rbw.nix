{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [ ../../shared/base/rbw.nix ];

  programs.rbw.settings = {
    email = lib.mkForce "b@robitzs.ch";
    base_url = lib.mkForce "https://vault.robitzs.ch";
    pinentry = lib.mkForce inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.rbw-pinentry;
  };
}
