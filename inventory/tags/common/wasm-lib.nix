# Make the wasm plugin library available as a NixOS module argument.
#
# After importing this module, any NixOS module can destructure `wasm`
# from its arguments and call evalNickelFile, fromYAML, etc.:
#
#   { wasm, ... }:
#   let cfg = wasm.evalNickelFile ./config.ncl;
#   in { services.foo.port = cfg.port; }
#
{ self, pkgs, ... }:
{
  _module.args.wasm = import "${self}/lib/wasm.nix" {
    plugins = self.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins;
  };
}
