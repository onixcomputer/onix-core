# Notification daemon settings — thin stub over notifications.ncl.
#
# Data and contracts live in notifications.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./notifications.ncl;
in
{
  options.notifications = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Notification daemon settings";
  };
}
