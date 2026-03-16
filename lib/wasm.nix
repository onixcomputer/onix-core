# Wasm plugin wrappers.
#
# Provides fromYAML, toYAML, fromINI as pure Nix functions backed
# by builtins.wasm. Requires the wasm-builtin experimental feature.
#
# Usage:
#   let wasm = import ./lib/wasm.nix { inherit plugins; };
#   in wasm.fromYAML (builtins.readFile ./config.yaml)
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

  # Parse an INI string into a nested attrset (section → key → value).
  fromINI =
    str:
    builtins.wasm {
      path = "${plugins}/ini_plugin.wasm";
      function = "fromINI";
    } str;
}
