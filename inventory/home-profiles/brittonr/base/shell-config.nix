# Shell configuration — thin stub over shell-config.ncl.
#
# Data and contracts live in shell-config.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./shell-config.ncl;
in
{
  options.shellConfig = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Shell prompt configuration";
  };
}
