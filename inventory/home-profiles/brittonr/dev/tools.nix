{ pkgs, inputs, ... }:
let
  tuicr = pkgs.callPackage ../../../../pkgs/tuicr { };
  tracey = pkgs.callPackage ../../../../pkgs/tracey { };
  dumbpipe = pkgs.callPackage ../../../../pkgs/dumbpipe { };
  sendme = pkgs.callPackage ../../../../pkgs/sendme { };
  nixdelta = inputs.nixdelta.packages.${pkgs.stdenv.hostPlatform.system}.default;
  kiEditor = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ki-editor;
  mercuryCli = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.mercury-cli;
  tigerstylePkgs = inputs.tigerstyle.packages.${pkgs.stdenv.hostPlatform.system};
  tigerstyleStandards = tigerstylePkgs.tigerstyle-standards or tigerstylePkgs.slotcar-standards;
in
{
  home.packages = with pkgs; [
    # Search and file tools
    ripgrep
    fd
    bat
    nixos-generators
    glow
    comma
    warp-terminal
    nh
    nix-search-tv
    deadnix
    statix
    dix
    nvd
    flake-edit
    nurl
    nil
    nix-init
    terranix
    nix-index
    nix-prefetch
    android-tools

    # Archive tools
    unzip

    # Network tools
    wget

    # Debug and system tools
    lsof
    ast-grep
    graphicsmagick
    tea
    sysdig

    # Code quality tools
    shellcheck
    ruff
    mypy

    # Parser and formatter tools
    tree-sitter
    stylua

    # TUI tools
    tuicr

    # AI/dev tooling
    tracey

    # Iroh P2P tools
    dumbpipe
    sendme

    # Flake inputs
    nixdelta
    kiEditor
    mercuryCli
    tigerstylePkgs.cargo-tigerstyle
    tigerstyleStandards
  ];
}
