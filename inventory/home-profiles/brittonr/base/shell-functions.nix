{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  wasm = import "${inputs.self}/lib/wasm.nix" {
    plugins = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins;
  };
  shellData = wasm.evalNickelFile ./shell-functions.ncl;
  sections = (lib.attrValues shellData.functions) ++ (lib.attrValues shellData.init);
in
{
  programs.fish.interactiveShellInit = lib.concatStringsSep "\n\n" sections;
}
