{
  inputs,
  lib,
  pkgs,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  basePackage = inputs.niri.packages.${system}.niri;
  compatibleLibdisplayInfo = pkgs.libdisplay-info_0_3;

  isLibdisplayInfo = dependency: (dependency.pname or "") == "libdisplay-info";
  replaceLibdisplayInfo =
    dependency: if isLibdisplayInfo dependency then compatibleLibdisplayInfo else dependency;
in
basePackage.overrideAttrs (
  previous:
  let
    previousBuildInputs = previous.buildInputs or [ ];
    matchingBuildInputs = lib.filter isLibdisplayInfo previousBuildInputs;
  in
  assert lib.assertMsg (
    builtins.length matchingBuildInputs == 1
  ) "the Niri package must have exactly one libdisplay-info build input";
  {
    # Niri's Rust dependency requires libdisplay-info >= 0.1.0 and < 0.4.0.
    buildInputs = map replaceLibdisplayInfo previousBuildInputs;
  }
)
