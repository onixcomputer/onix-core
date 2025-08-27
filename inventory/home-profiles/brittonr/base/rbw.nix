{ lib, ... }:
{
  imports = [ ../../alex/base/rbw.nix ];

  programs.rbw.settings.email = lib.mkForce "b@robitzs.ch";
  programs.rbw.settings.base_url = lib.mkForce "https://vault.robitzs.ch";
}
