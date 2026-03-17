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

    # Nickel plugin: evalNickel (string input)
    wasm-evalNickel-int = mkWasmTest "evalNickel-int" ''
      builtins.wasm {
        path = ${plugins}/nickel_plugin.wasm;
        function = "evalNickel";
      } "42"
    '' "42";

    wasm-evalNickel-record = mkWasmTest "evalNickel-record" ''
      builtins.wasm {
        path = ${plugins}/nickel_plugin.wasm;
        function = "evalNickel";
      } "{ x = 1, y = \"hello\" }"
    '' ''{ x = 1; y = "hello"; }'';

    wasm-evalNickel-list = mkWasmTest "evalNickel-list" ''
      builtins.wasm {
        path = ${plugins}/nickel_plugin.wasm;
        function = "evalNickel";
      } "[1, 2, 3]"
    '' "[ 1 2 3 ]";

    wasm-evalNickel-nested = mkWasmTest "evalNickel-nested" ''
      builtins.wasm {
        path = ${plugins}/nickel_plugin.wasm;
        function = "evalNickel";
      } "{ a = { b = [true, null] } }"
    '' "{ a = { b = [ true null ]; }; }";

    wasm-evalNickel-let = mkWasmTest "evalNickel-let" ''
      builtins.wasm {
        path = ${plugins}/nickel_plugin.wasm;
        function = "evalNickel";
      } "let double = fun x => x * 2 in { result = double 21 }"
    '' "{ result = 42; }";

    # Nickel plugin: evalNickelFile (path input)
    wasm-evalNickelFile-simple =
      let
        ncl = pkgs.writeText "test.ncl" ''{ port = 8080, host = "localhost" }'';
      in
      mkWasmTest "evalNickelFile-simple" ''
        builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelFile";
        } ${ncl}
      '' ''{ host = "localhost"; port = 8080; }'';

    wasm-evalNickel-error =
      pkgs.runCommand "wasm-check-evalNickel-error" { nativeBuildInputs = [ nixWasm ]; }
        ''
          export HOME=$TMPDIR
          # A malformed Nickel expression must cause nix eval to fail
          if nix eval --store dummy:// --offline \
              --extra-experimental-features 'nix-command flakes wasm-builtin' \
              --impure --expr '
                builtins.wasm {
                  path = ${plugins}/nickel_plugin.wasm;
                  function = "evalNickel";
                } "{ x = }"
              ' 2>/dev/null; then
            echo "FAIL: evalNickel-error — expected failure but got success"
            exit 1
          else
            echo "PASS: evalNickel-error — malformed Nickel correctly caused an error"
            echo "ok" > $out
          fi
        '';

    wasm-evalNickelFile-import =
      let
        testDir = pkgs.runCommand "nickel-import-test" { } ''
          mkdir -p $out
          cat > $out/main.ncl <<'EOF'
          let lib = import "lib.ncl" in { result = lib.value + 1 }
          EOF
          cat > $out/lib.ncl <<'EOF'
          { value = 41 }
          EOF
        '';
      in
      mkWasmTest "evalNickelFile-import" ''
        builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelFile";
        } ${testDir}/main.ncl
      '' "{ result = 42; }";

    wasm-evalNickelFile-nested-import =
      let
        testDir = pkgs.runCommand "nickel-nested-import-test" { } ''
          mkdir -p $out/sub
          cat > $out/main.ncl <<'EOF'
          let a = import "sub/a.ncl" in { result = a.val }
          EOF
          cat > $out/sub/a.ncl <<'EOF'
          let b = import "../b.ncl" in { val = b.x * 2 }
          EOF
          cat > $out/b.ncl <<'EOF'
          { x = 10 }
          EOF
        '';
      in
      mkWasmTest "evalNickelFile-nested-import" ''
        builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelFile";
        } ${testDir}/main.ncl
      '' "{ result = 20; }";

    wasm-evalNickelFile-import-error =
      let
        testDir = pkgs.runCommand "nickel-import-error-test" { } ''
          mkdir -p $out
          cat > $out/main.ncl <<'EOF'
          let x = import "nonexistent.ncl" in x
          EOF
        '';
      in
      pkgs.runCommand "wasm-check-evalNickelFile-import-error" { nativeBuildInputs = [ nixWasm ]; } ''
        export HOME=$TMPDIR
        if nix eval --store dummy:// --offline \
            --extra-experimental-features 'nix-command flakes wasm-builtin' \
            --impure --expr '
              builtins.wasm {
                path = ${plugins}/nickel_plugin.wasm;
                function = "evalNickelFile";
              } ${testDir}/main.ncl
            ' 2>/dev/null; then
          echo "FAIL: expected import error but got success"
          exit 1
        else
          echo "PASS: missing import correctly caused an error"
          echo "ok" > $out
        fi
      '';

    wasm-evalNickelFile-stdlib =
      let
        ncl = pkgs.writeText "stdlib.ncl" ''
          { result = std.array.length [1, 2, 3, 4, 5] }
        '';
      in
      mkWasmTest "evalNickelFile-stdlib" ''
        builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelFile";
        } ${ncl}
      '' "{ result = 5; }";
  };
}
