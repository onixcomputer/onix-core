{ pkgs, ... }:
{
  home.packages = with pkgs; [
    orca-slicer
    # bambu-studio
    gimp
    figma-agent
    penpot-desktop
    cables
    logseq
  ];
}
