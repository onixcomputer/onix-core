# Custom transposed module for analysis tools
# Exposes infrastructure analysis tools as dedicated flake outputs
# Access with: nix build .#analysisTools.<system>.<tool>
# Tools: acl, vars, tags, roster
{ lib, flake-parts-lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (flake-parts-lib) mkTransposedPerSystemModule;
in
mkTransposedPerSystemModule {
  name = "analysisTools";
  option = mkOption {
    type = types.lazyAttrsOf types.package;
    default = { };
    description = ''
      Infrastructure analysis tools exposed as flake outputs.

      Available tools:
      - acl: Analyze SOPS secret ownership and access control
      - vars: Analyze clan vars ownership and distribution
      - tags: Analyze machine tags and their assignments
      - roster: Analyze user roster configurations

      Access with: nix build .#analysisTools.<system>.<tool>
      Example: nix build .#analysisTools.x86_64-linux.acl
    '';
  };
  file = ./analysis-tools.nix;
}
