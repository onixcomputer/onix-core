# XDG config — thin stub over xdg.ncl.
#
# Data and contracts live in xdg.ncl.
# This module wires user directories and MIME associations
# into home-manager's xdg options.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./xdg.ncl;

  # Flatten grouped mimeApps into a single attrset.
  flatMime = builtins.foldl' (acc: group: acc // group) { } (builtins.attrValues data.mimeApps);
in
{
  home.preferXdgDirectories = true;

  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      inherit (data.userDirs)
        documents
        download
        music
        pictures
        videos
        ;
      extraConfig = builtins.mapAttrs (_: lib.mkForce) data.userDirs.extra;
    };

    mimeApps = {
      enable = true;
      defaultApplications = flatMime;
    };

    configFile."mimeapps.list".force = true;
  };
}
