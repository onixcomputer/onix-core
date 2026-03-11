{ pkgs, ... }:
{
  nixpkgs.config.permittedInsecurePackages = [
    "libsoup-2.74.3"
  ];

  environment.systemPackages = with pkgs; [
    # 3D CAD/modeling
    openscad
    openscad-lsp

    # PCB design
    kicad
    turbocase # Generate OpenSCAD case templates from KiCAD PCBs

    # 2D graphics / vector editing
    graphite
  ];
}
