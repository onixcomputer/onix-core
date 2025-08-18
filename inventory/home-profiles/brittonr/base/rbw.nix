{ lib, ... }:
{
  imports = [ ../../alex/base/rbw.nix ];

  programs.rbw.settings.email = lib.mkForce "b@robitzs.ch";
}
