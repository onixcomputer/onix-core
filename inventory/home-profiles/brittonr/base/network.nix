# Network connectivity settings — thin stub over network.ncl.
#
# Data and contracts live in network.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./network.ncl;
in
{
  options.network = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Network connectivity settings";
  };
}
