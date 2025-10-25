# Terranix JSON Generation Module
{ lib, pkgs }:

let
  eval = import ./eval.nix { inherit lib; };
in
{
  # Generate JSON configuration from terranix module
  generateTerranixJson =
    {
      # Terranix module to evaluate
      module,
      # Settings/arguments to pass to the module
      moduleArgs ? { },
      # Output file name
      fileName ? "terraform.json",
      # Pretty print JSON
      prettyPrintJson ? false,
      # Validation options
      validate ? true,
      # Debug mode
      debug ? false,
    }:
    let
      evaluated = eval.evalTerranixModule {
        inherit
          module
          moduleArgs
          validate
          debug
          ;
      };

    in
    if prettyPrintJson then
      pkgs.runCommand fileName { nativeBuildInputs = [ pkgs.jq ]; } ''
        echo '${builtins.toJSON evaluated}' | jq . > $out
      ''
    else
      pkgs.writeText fileName (builtins.toJSON evaluated);
}
