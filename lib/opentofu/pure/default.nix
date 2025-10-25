# OpenTofu Pure Functions Library
#
# Re-exports all pure functions from the modular pure library.
# These functions are pkgs-independent and can be used with nix-unit
# for fast testing and validation.
#
# This module provides a single entry point for all pure OpenTofu
# utility functions organized by category:
#
# - credentials: Credential mapping and systemd LoadCredential support
# - paths: Consistent path and name generation utilities
# - validation: Configuration validation and merging functions
# - utilities: Configuration analysis and debugging utilities
# - backends: Terraform backend configuration generation
{ lib }:

let
  credentials = import ./credentials.nix { inherit lib; };
  paths = import ./paths.nix null;
  validation = import ./validation.nix { inherit lib; };
  utilities = import ./utilities.nix { inherit lib; };
  backends = import ./backends.nix null;
in

# Merge all modules into a single attribute set for easy access
credentials // paths // validation // utilities // backends
