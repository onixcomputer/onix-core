# CLI tools, analysis utilities, and workflow helpers.
#
# Composes all parts/tool modules into a single adios-flake module.
# Explicit inherit prevents nixfmt from stripping args that adios-flake
# needs for system-dependency detection.
{
  pkgs,
  lib,
  ...
}:
let
  # All parts take { pkgs, ... } — pass full set so they get whatever they need
  callPart = p: (import p) { inherit pkgs lib; };

  parts = map callPart [
    ../parts/sops-viz.nix
    ../parts/merge-when-green.nix
    ../parts/nix-eval-warnings.nix
    ../parts/iroh-ssh.nix
    ../parts/claude-md.nix
    ../parts/tuicr.nix
    ../parts/tracey.nix
    ../parts/ccusage.nix
    ../parts/abp.nix
    ../parts/branchfs.nix
    ../parts/updater.nix
    ../parts/iroh-tools.nix
  ];

  merged = builtins.foldl' (acc: part: lib.recursiveUpdate acc part) { } parts;
in
merged
