# SSH config — thin stub over ssh.ncl.
#
# Data and contracts live in ssh.ncl.
# This module wires the validated data into home-manager's
# programs.ssh options.
{
  inputs,
  pkgs,
  ...
}:
let
  wasm = import "${inputs.self}/lib/wasm.nix" {
    plugins = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins;
  };
  data = wasm.evalNickelFile ./ssh.ncl;

  # Build matchBlocks from NCL data.
  # The wildcard block gets defaults; each named host gets
  # the shared identityFile + identitiesOnly unless it has its own.
  gitHosts = builtins.mapAttrs (
    _name: block:
    block
    // {
      identityFile = block.identityFile or data.identityFile;
      identitiesOnly = block.identitiesOnly or true;
    }
  ) data.hosts;
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

    matchBlocks = {
      "*" = data.defaults;
    }
    // gitHosts;
  };
}
