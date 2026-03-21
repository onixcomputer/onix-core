# Editor settings — thin stub over editor.ncl.
#
# Data and contracts live in editor.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./editor.ncl;
in
{
  options.editor = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Editor settings for text width, wrapping, auto-save, and diagnostics";
  };
}
