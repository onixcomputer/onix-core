# Make the wasm plugin library and pre-evaluated shared data available
# as NixOS module arguments.
#
# After importing this module, any NixOS module can destructure `wasm`
# from its arguments and call evalNickelFile, fromYAML, etc.:
#
#   { wasm, ... }:
#   let cfg = wasm.evalNickelFile ./config.ncl;
#   in { services.foo.port = cfg.port; }
#
# `nclMachines` provides the pre-evaluated machines.ncl data, avoiding
# redundant WASM evaluations across tag modules.
#
{ self, pkgs, ... }:
let
  wasm = import "${self}/lib/wasm.nix" {
    plugins = self.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins;
  };
in
{
  _module.args = {
    inherit wasm;
    nclMachines = (wasm.evalNickelFile ../../core/machines.ncl).machines;
  };
}
