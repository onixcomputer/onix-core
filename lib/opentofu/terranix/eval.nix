# Terranix Module Evaluation
{ lib }:

let
  validation = import ./validation.nix { inherit lib; };
in
{
  # Evaluate terranix module and return JSON configuration
  evalTerranixModule =
    {
      # Terranix module to evaluate
      module,
      # Settings/arguments to pass to the module
      moduleArgs ? { },
      # Debug mode - includes source information
      debug ? false,
      # Validation mode - strict type checking
      validate ? true,
    }:
    let
      # Use only the provided moduleArgs (don't add extra lib/pkgs that might conflict)
      evalArgs = moduleArgs;

      # Evaluate the terranix module
      evaluated =
        if builtins.isFunction module then
          module evalArgs
        else if builtins.isPath module then
          import module evalArgs
        else if builtins.isString module then
          import (/. + module) evalArgs
        else
          module;

      # Validate the result if requested
      validatedResult = if validate then validation.validateTerranixConfig evaluated else evaluated;

      # Add debug information if requested
      resultWithDebug =
        if debug then
          validatedResult
          // {
            _debug = {
              moduleSource = toString module;
              evaluationArgs = builtins.attrNames evalArgs;
            };
          }
        else
          validatedResult;

    in
    resultWithDebug;
}
