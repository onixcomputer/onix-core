{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Core Typst typesetting system
    typst

    # Formatting and development tools
    typstyle # Format your typst source code
    typst-live # Hot reloading for typst files
    typstwriter # Integrated editor for typst

    # Additional useful packages
    typstPackages.cetz # Drawing package (TikZ-like)
    typstPackages.algo # Algorithm typesetting
    typstPackages.tbl # Complex tables
    typstPackages.unify # Format numbers, units, and ranges
  ];

  # Enable fontconfig for better font handling with Typst
  fonts.enableDefaultPackages = true;
}
