# Disable NixOS manual, info pages, and doc generation.
# Saves closure size (~350MB) and eval time on headless/server machines
# where nobody reads local docs.
#
# Apply to machines that don't have a desktop environment.
# Adapted from Mic92/dotfiles nixosModules/minimal-docs.nix.
{ lib, ... }:
{
  documentation = {
    nixos.enable = lib.mkForce false;
    info.enable = false;
    doc.enable = false;
  };
}
