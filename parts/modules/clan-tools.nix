# Custom transposed module for clan infrastructure tools
# Exposes clan management tools as dedicated flake outputs
# Access with: nix build .#clanTools.<system>.<tool>
# Tools: cloud
{ lib, flake-parts-lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (flake-parts-lib) mkTransposedPerSystemModule;
in
mkTransposedPerSystemModule {
  name = "clanTools";
  option = mkOption {
    type = types.lazyAttrsOf types.package;
    default = { };
    description = ''
      Clan infrastructure management tools exposed as flake outputs.

      Available tools:
      - cloud: Cloud infrastructure management (OpenTofu/Terranix wrapper)

      Access with: nix build .#clanTools.<system>.<tool>
      Example: nix run .#clanTools.x86_64-linux.cloud -- status
    '';
  };
  file = ./clan-tools.nix;
}
