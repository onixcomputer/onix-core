# Service timing settings — thin stub over services.ncl.
#
# Data and contracts live in services.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./services.ncl;
in
{
  options.serviceTiming = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Shared systemd service timing values";
  };
}
