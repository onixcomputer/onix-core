{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Core Typst typesetting system
    typst

    # Development and formatting tools
    typstyle # Code formatter
    typst-live # Hot reloading during development
    typstwriter # Integrated editor

    # Useful Typst packages for document creation
    typstPackages.cetz # Drawing and diagrams (TikZ-inspired)
    typstPackages.algo # Algorithm typesetting
    typstPackages.tbl # Advanced table layouts
    typstPackages.unify # Number and unit formatting
    typstPackages.ilm # Versatile document template
    typstPackages.may # Simple document template
  ];

  # Set up file associations for Typst files
  xdg.mimeApps.defaultApplications = {
    "text/x-typst" = [ "typstwriter.desktop" ];
  };
}
