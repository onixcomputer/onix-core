{ pkgs, inputs, ... }:
let
  tuicr = pkgs.callPackage ../../../../pkgs/tuicr { };
  tracey = pkgs.callPackage ../../../../pkgs/tracey { };
  dumbpipe = pkgs.callPackage ../../../../pkgs/dumbpipe { };
  sendme = pkgs.callPackage ../../../../pkgs/sendme { };
  nixdelta = inputs.nixdelta.packages.${pkgs.stdenv.hostPlatform.system}.default;
  kiEditor = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ki-editor;
  mercuryCli = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.mercury-cli;
  cairnUpstream = inputs.cairn.packages.${pkgs.stdenv.hostPlatform.system}.cairn;
  cairnCargoDeps = pkgs.rustPlatform.importCargoLock {
    lockFile = "${inputs.cairn}/Cargo.lock";
    # Fixed-output sources let remote hosts evaluate Cairn without GitHub credentials.
    outputHashes = {
      "artifact-auth-core-0.1.0" = "sha256-2cM912L2YXVnVX9LquwhAPKyjPP/z/oFQRe7Qq9bHHE=";
      "artifact-auth-ed25519-0.1.0" = "sha256-2cM912L2YXVnVX9LquwhAPKyjPP/z/oFQRe7Qq9bHHE=";
      "nickel-export-core-0.1.0" = "sha256-dV4+/jghpJ89F5DHprdjxyru8kllMAurS2DsBGn/ibA=";
      "rat-canvas-0.1.0" = "sha256-WHMtm38pQirmjZ/5Ua0unGhj4pIDaEixXG1pBUYWmTQ=";
      "rat-nodegraph-0.1.0" = "sha256-WHMtm38pQirmjZ/5Ua0unGhj4pIDaEixXG1pBUYWmTQ=";
    };
  };
  cairn = cairnUpstream.overrideAttrs (_old: {
    cargoDeps = cairnCargoDeps;
  });
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
    cairn
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
