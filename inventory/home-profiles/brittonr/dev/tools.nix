{ pkgs, inputs, ... }:
let
  tuicr = pkgs.callPackage ../../../../pkgs/tuicr { };
  tracey = pkgs.callPackage ../../../../pkgs/tracey { };
  dumbpipe = pkgs.callPackage ../../../../pkgs/dumbpipe { };
  sendme = pkgs.callPackage ../../../../pkgs/sendme { };
  nixdelta = inputs.nixdelta.packages.${pkgs.stdenv.hostPlatform.system}.default;
  kuna = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.kuna;
  kiEditor = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ki-editor;
  mercuryCli = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.mercury-cli;
  primeAgent = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.prime-agent;
  cairnUpstream = inputs.cairn.packages.${pkgs.stdenv.hostPlatform.system}.cairn;
  cairnArtifactInput = inputs.cairn.inputs.artifact;
  cairnArtifactGitUrl = "ssh://git@github.com/OnixResearch/onix-artifact.git";
  cairnFetchGit =
    args@{ url, rev, ... }:
    if url == cairnArtifactGitUrl && rev == cairnArtifactInput.rev then
      cairnArtifactInput
    else
      pkgs.fetchgit args;
  importCairnCargoLock =
    pkgs.callPackage "${pkgs.path}/pkgs/build-support/rust/import-cargo-lock.nix"
      {
        fetchgit = cairnFetchGit;
      };
  cairnCargoDeps = importCairnCargoLock {
    lockFile = "${inputs.cairn}/Cargo.lock";
    outputHashes = {
      "artifact-auth-core-0.1.0" = "sha256-2cM912L2YXVnVX9LquwhAPKyjPP/z/oFQRe7Qq9bHHE=";
      "artifact-auth-ed25519-0.1.0" = "sha256-2cM912L2YXVnVX9LquwhAPKyjPP/z/oFQRe7Qq9bHHE=";
      "nickel-export-core-0.1.0" = "sha256-dV4+/jghpJ89F5DHprdjxyru8kllMAurS2DsBGn/ibA=";
      "rat-canvas-0.1.0" = "sha256-WHMtm38pQirmjZ/5Ua0unGhj4pIDaEixXG1pBUYWmTQ=";
      "rat-nodegraph-0.1.0" = "sha256-WHMtm38pQirmjZ/5Ua0unGhj4pIDaEixXG1pBUYWmTQ=";
    };
  };
  cairn = cairnUpstream.overrideAttrs (old: {
    cargoDeps = cairnCargoDeps;
    passthru = (old.passthru or { }) // {
      usesUploadedArtifactInput = true;
    };
  });
  octetPkgs = inputs.tigerstyle.packages.${pkgs.stdenv.hostPlatform.system};
  octetStandards = octetPkgs.octet-standards;
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
    kuna
    primeAgent

    # Iroh P2P tools
    dumbpipe
    sendme

    # Flake inputs
    nixdelta
    kiEditor
    mercuryCli
    octetPkgs.cargo-octet
    octetStandards
  ];
}
