# Wasm plugin wrappers.
#
# Provides format parsers (fromYAML, toYAML, fromINI) and a Nickel
# evaluator (evalNickel, evalNickelFile) as pure Nix functions backed
# by builtins.wasm. Requires the wasm-builtin experimental feature.
#
# Usage:
#   let wasm = import ./lib/wasm.nix { inherit plugins; };
#   in wasm.fromYAML (builtins.readFile ./config.yaml)
#   in wasm.evalNickel ''{ x = 1, y = "hello" }''
#   in wasm.evalNickelFile ./config.ncl
#
{ plugins }:
{
  # Parse a YAML string into a list of Nix values (one per YAML document).
  # Single-document files: use `builtins.head (fromYAML str)`.
  fromYAML =
    str:
    builtins.wasm {
      path = "${plugins}/yaml_plugin.wasm";
      function = "fromYAML";
    } str;

  # Serialize a list of Nix values into a YAML string (multi-document).
  toYAML =
    vals:
    builtins.wasm {
      path = "${plugins}/yaml_plugin.wasm";
      function = "toYAML";
    } vals;

  # Evaluate a Nickel source string, returning the result as a Nix value.
  # Single values, records, lists, and nested structures are all supported.
  # The full Nickel standard library is available during evaluation.
  #
  # Usage: wasm.evalNickel ''{ x = 1, y = "hello" }''
  evalNickel =
    str:
    builtins.wasm {
      path = "${plugins}/nickel_plugin.wasm";
      function = "evalNickel";
    } str;

  # Evaluate a Nickel file from a Nix path, returning the result as a Nix value.
  # The file is read via the host WASM ABI (not std::fs).
  # Relative `import` statements are supported — imported files are resolved
  # relative to the input file's directory via the host ABI.
  # Standard library functions are available.
  #
  # Usage: wasm.evalNickelFile ./config.ncl
  evalNickelFile =
    path:
    builtins.wasm {
      path = "${plugins}/nickel_plugin.wasm";
      function = "evalNickelFile";
    } path;

  # Evaluate a Nickel file with Nix arguments applied.
  # The .ncl file must be a function: fun { key1, key2, .. } => ...
  # The args attrset is converted to Nickel and applied as the argument.
  #
  # Nix args are recursively converted to native Nickel values
  # (records, arrays, strings, numbers, bools, null). Non-data
  # Nix values (functions, paths, derivations) pass through as
  # opaque ForeignId handles.
  #
  # Usage: wasm.evalNickelFileWith ./config.ncl { cores = 8; ramGB = 32; }
  evalNickelFileWith =
    path: args:
    builtins.wasm
      {
        path = "${plugins}/nickel_plugin.wasm";
        function = "evalNickelFileWith";
      }
      {
        file = path;
        inherit args;
      };

  # Evaluate a Nickel source string with Nix arguments applied.
  # The source must be a function: fun { key1, key2, .. } => ...
  #
  # Usage: wasm.evalNickelWith "fun { x, .. } => x + 1" { x = 41; }
  evalNickelWith =
    source: args:
    builtins.wasm
      {
        path = "${plugins}/nickel_plugin.wasm";
        function = "evalNickelWith";
      }
      {
        inherit source;
        inherit args;
      };

  # Parse an INI string into a nested attrset (section → key → value).
  fromINI =
    str:
    builtins.wasm {
      path = "${plugins}/ini_plugin.wasm";
      function = "fromINI";
    } str;
}
