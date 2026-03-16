# Functional tests for builtins.wasm plugins.
#
# Builds the wasm-enabled nix, then runs it against each plugin
# to verify end-to-end functionality. This catches:
# - ABI mismatches between nix fork and plugin bindings
# - wasm-opt stripping required features
# - Plugin logic regressions
{
  self,
  self',
  pkgs,
  system,
  ...
}:
let
  # The wasm-enabled nix binary from the overlay
  nixWasm = self.inputs.nix-wasm.packages.${system}.nix.overrideAttrs (_: {
    doCheck = false;
  });

  plugins = self'.packages.wasm-plugins;

  mkWasmTest =
    name: expr: expected:
    pkgs.runCommand "wasm-check-${name}" { nativeBuildInputs = [ nixWasm ]; } ''
      export HOME=$TMPDIR
      result=$(nix eval --store dummy:// --offline --extra-experimental-features 'nix-command flakes wasm-builtin' --impure --expr '${expr}')
      expected='${expected}'
      if [ "$result" = "$expected" ]; then
        echo "PASS: ${name}"
        echo "$result" > $out
      else
        echo "FAIL: ${name}"
        echo "  expected: $expected"
        echo "  got:      $result"
        exit 1
      fi
    '';
in
{
  checks = {
    wasm-fromYAML = mkWasmTest "fromYAML" ''
      builtins.wasm {
        path = ${plugins}/yaml_plugin.wasm;
        function = "fromYAML";
      } "x: 42\n"
    '' "[ { x = 42; } ]";

    wasm-toYAML = mkWasmTest "toYAML" ''
      builtins.wasm {
        path = ${plugins}/yaml_plugin.wasm;
        function = "toYAML";
      } [ { a = 1; } ]
    '' ''"---\na: 1\n"'';

    wasm-fromINI = mkWasmTest "fromINI" ''
      builtins.wasm {
        path = ${plugins}/ini_plugin.wasm;
        function = "fromINI";
      } "[s]\nk = v\n"
    '' ''{ s = { k = "v"; }; }'';
  };
}
