# SSH config — thin stub over ssh.ncl.
#
# Data and contracts live in ssh.ncl.
# This module wires the validated data into home-manager's
# programs.ssh options.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  wasm = import "${inputs.self}/lib/wasm.nix" {
    plugins = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins;
  };
  data = wasm.evalNickelFile ./ssh.ncl;

  mkDefaultSettings = defaults: {
    AddKeysToAgent = defaults.addKeysToAgent;
    Compression = defaults.compression;
    ForwardAgent = defaults.forwardAgent;
  };

  mkHostSettings =
    _name: block:
    lib.filterAttrs (_: value: value != null) {
      HostName = block.hostname or null;
      User = block.user or null;
      IdentityFile = block.identityFile or data.identityFile;
      IdentitiesOnly = block.identitiesOnly or true;
      HostKeyAlias = block.hostKeyAlias or null;
    };

  hostSettings = builtins.mapAttrs mkHostSettings data.hosts;
in
{
  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = ''
      IdentityFile ${data.identityFile}
      AddressFamily inet
    '';

    settings = {
      "*" = mkDefaultSettings data.defaults;
    }
    // hostSettings;
  };
}
