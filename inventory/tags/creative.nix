{ pkgs, ... }:
let
  # This tag shares the global package set with desktop Home Manager and service
  # modules. Match exact derivation names so evaluation fails again when nixpkgs
  # changes insecure dependency versions. Package-level marks without versions
  # use nixpkgs' exact insecure identifier.
  allowedInsecurePackageNames = [
    "electron-39.8.10"
    "librewolf"
    "librewolf-151.0.2-1"
    "librewolf-unwrapped-151.0.2-1"
    "libsoup-2.74.3"
    "olm-3.2.16"
  ];

  packageNameWithVersion =
    pkg: pkg.name or (if pkg ? pname && pkg ? version then "${pkg.pname}-${pkg.version}" else "");
in
{
  nixpkgs.config.allowInsecurePredicate =
    pkg: builtins.elem (packageNameWithVersion pkg) allowedInsecurePackageNames;

  environment.systemPackages = with pkgs; [
    # 3D CAD/modeling
    # Stable openscad currently fails to link against nixpkgs' GLEW/GLX stack.
    openscad-unstable
    openscad-lsp

    # PCB design
    kicad
    turbocase # Generate OpenSCAD case templates from KiCAD PCBs

    # 2D graphics / vector editing
    graphite
  ];
}
