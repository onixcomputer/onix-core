{
  pkgs,
  inputs,
  lib,
  ...
}:
let
  tuicr = pkgs.callPackage ../../../../pkgs/tuicr { };
  tracey = pkgs.callPackage ../../../../pkgs/tracey { };
  dumbpipe = pkgs.callPackage ../../../../pkgs/dumbpipe { };
  sendme = pkgs.callPackage ../../../../pkgs/sendme { };
  nixdelta = inputs.nixdelta.packages.${pkgs.stdenv.hostPlatform.system}.default;
  kuna = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.kuna;
  kiEditor = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ki-editor;
  mercuryCli = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.mercury-cli;
  kli = inputs.kli.packages.${pkgs.stdenv.hostPlatform.system}.default;
  primeAgent = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.prime-agent;
  cairnUpstream = inputs.cairn.packages.${pkgs.stdenv.hostPlatform.system}.cairn;
  cairnInputs = inputs.cairn.inputs;
  cairnUploadedSources = [
    {
      url = "ssh://git@github.com/OnixResearch/onix-artifact.git";
      input = cairnInputs.artifact;
    }
    {
      url = "https://git.onix.computer/z2CpqLFpdP36fZXYUK5ZNWxMibpCo.git";
      input = cairnInputs.bounded-exec;
    }
    {
      url = "https://seed.radicle.garden/z3cWBCK7VPbEmbL5MAvKJWKjCE745.git";
      input = cairnInputs.cap-root;
    }
    {
      url = "https://seed.radicle.garden/z3tAR4For7qw8ZirkJzoDw1VNDDLM.git";
      input = cairnInputs.durable-file-publication;
    }
    {
      url = "https://seed.radicle.garden/z2wsvXm5S2sJGvuV1k5JHiwi1PbKE.git";
      input = cairnInputs.kiln-core;
    }
    {
      url = "ssh://git@github.com/OnixResearch/mantle.git";
      input = cairnInputs.mantle-build-contract;
    }
    {
      url = "https://github.com/OnixResearch/nickel-export";
      input = cairnInputs.nickel-export;
    }
  ];
  cairnFetchGit =
    args@{ url, rev, ... }:
    let
      source = lib.findFirst (
        candidate: candidate.url == url && candidate.input.rev == rev
      ) null cairnUploadedSources;
    in
    if source != null then
      assert
        (args.sha256 or null) == source.input.narHash
        || throw "Cairn Cargo source hash does not match its uploaded input.";
      source.input
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
      # Bind Cargo hashes to the same locked sources that Clan uploads.
      "artifact-auth-core-0.1.0" = cairnInputs.artifact.narHash;
      "artifact-auth-ed25519-0.1.0" = cairnInputs.artifact.narHash;
      "bounded-exec-0.1.0" = cairnInputs.bounded-exec.narHash;
      "bounded-exec-core-0.1.0" = cairnInputs.bounded-exec.narHash;
      "cap-root-core-0.1.0" = cairnInputs.cap-root.narHash;
      "durable-file-publication-0.1.0" = cairnInputs.durable-file-publication.narHash;
      "kiln-core-0.1.0" = cairnInputs.kiln-core.narHash;
      "mantle-build-contract-0.1.0" = cairnInputs.mantle-build-contract.narHash;
      "nickel-export-core-0.1.0" = cairnInputs.nickel-export.narHash;
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
    devenv
    (lib.lowPrio secretspec)
    tracey
    kuna
    kli
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
