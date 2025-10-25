# Terranix Library - Re-exports all terranix functions
{ lib, pkgs }:

let
  types = import ./types.nix { inherit lib; };
  validation = import ./validation.nix { inherit lib; };
  eval = import ./eval.nix { inherit lib; };
  generation = import ./generation.nix { inherit lib pkgs; };
  testing = import ./testing.nix { inherit lib; };
  utilities = import ./utilities.nix null;
in
rec {
  # Re-export all functions maintaining the same API as the original terranix.nix

  # Type definitions
  inherit (types)
    terranixModuleType
    terranixConfigType
    moduleArgsType
    evalOptionsType
    generationOptionsType
    testCaseType
    deploymentServiceOptionsType
    ;

  # Validation functions
  inherit (validation)
    validateTerranixConfig
    formatTerranixError
    ;

  # Evaluation functions
  inherit (eval)
    evalTerranixModule
    ;

  # Generation functions
  inherit (generation)
    generateTerranixJson
    ;

  # Testing and introspection functions
  inherit (testing)
    testTerranixModule
    introspectTerranixModule
    ;

  # Utility functions
  inherit (utilities)
    mkTerranixModule
    jsonToTerranixModule
    ;
}
