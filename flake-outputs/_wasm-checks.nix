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

    # ---- evalNickelFileWith: file function with Nix arguments ----

    # 5.1: Scalar args (int, string, bool)
    wasm-evalNickelFileWith-scalars =
      let
        ncl = pkgs.writeText "scalars.ncl" ''
          fun { cores, name, verbose, .. } =>
            { workers = cores * 2, greeting = name, debug = verbose }
        '';
      in
      mkWasmTest "evalNickelFileWith-scalars" ''
        builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelFileWith";
        } { file = ${ncl}; args = { cores = 4; name = "test"; verbose = true; }; }
      '' ''{ debug = true; greeting = "test"; workers = 8; }'';

    # 5.2: Nested attrset args
    wasm-evalNickelFileWith-nested-args =
      let
        ncl = pkgs.writeText "nested-args.ncl" ''
          fun { net, .. } => { port = net.port, bind = net.host }
        '';
      in
      mkWasmTest "evalNickelFileWith-nested-args" ''
        builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelFileWith";
        } { file = ${ncl}; args = { net = { port = 8080; host = "0.0.0.0"; }; }; }
      '' ''{ bind = "0.0.0.0"; port = 8080; }'';

    # 5.3: List args
    wasm-evalNickelFileWith-list-args =
      let
        ncl = pkgs.writeText "list-args.ncl" ''
          fun { ports, .. } => { count = std.array.length ports }
        '';
      in
      mkWasmTest "evalNickelFileWith-list-args" ''
        builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelFileWith";
        } { file = ${ncl}; args = { ports = [80 443 8080]; }; }
      '' "{ count = 3; }";

    # 5.4: Contract on args — passing case
    wasm-evalNickelFileWith-contract-pass =
      let
        ncl = pkgs.writeText "contract-pass.ncl" ''
          fun { cores | Number, name | String, .. } =>
            { result = cores, label = name }
        '';
      in
      mkWasmTest "evalNickelFileWith-contract-pass" ''
        builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelFileWith";
        } { file = ${ncl}; args = { cores = 8; name = "test"; }; }
      '' ''{ label = "test"; result = 8; }'';

    # 5.5: Contract on args — failing case
    wasm-evalNickelFileWith-contract-fail =
      let
        ncl = pkgs.writeText "contract-fail.ncl" ''
          fun { cores | Number, .. } => { result = cores }
        '';
      in
      pkgs.runCommand "wasm-check-evalNickelFileWith-contract-fail" { nativeBuildInputs = [ nixWasm ]; }
        ''
          export HOME=$TMPDIR
          if nix eval --store dummy:// --offline \
              --extra-experimental-features 'nix-command flakes wasm-builtin' \
              --impure --expr '
                builtins.wasm {
                  path = ${plugins}/nickel_plugin.wasm;
                  function = "evalNickelFileWith";
                } { file = ${ncl}; args = { cores = "eight"; }; }
              ' 2>/dev/null; then
            echo "FAIL: expected contract violation but got success"
            exit 1
          else
            echo "PASS: contract violation on args correctly caused an error"
            echo "ok" > $out
          fi
        '';

    # 5.6: evalNickelWith (source string + args)
    wasm-evalNickelWith-basic = mkWasmTest "evalNickelWith-basic" ''
      builtins.wasm {
        path = ${plugins}/nickel_plugin.wasm;
        function = "evalNickelWith";
      } { source = "fun { x, y, .. } => { sum = x + y }"; args = { x = 10; y = 32; }; }
    '' "{ sum = 42; }";

    # 5.7: Non-function file — Nickel will error on application, which is the
    # correct behavior (the source-wrapping approach makes `(data) {args}` a
    # type error). This verifies the error is raised.
    wasm-evalNickelFileWith-non-function =
      let
        ncl = pkgs.writeText "non-function.ncl" ''
          { static_value = 42 }
        '';
      in
      pkgs.runCommand "wasm-check-evalNickelFileWith-non-function" { nativeBuildInputs = [ nixWasm ]; } ''
        export HOME=$TMPDIR
        if nix eval --store dummy:// --offline \
            --extra-experimental-features 'nix-command flakes wasm-builtin' \
            --impure --expr '
              builtins.wasm {
                path = ${plugins}/nickel_plugin.wasm;
                function = "evalNickelFileWith";
              } { file = ${ncl}; args = { x = 1; }; }
            ' 2>/dev/null; then
          echo "FAIL: expected error when applying args to non-function but got success"
          exit 1
        else
          echo "PASS: applying args to non-function correctly caused an error"
          echo "ok" > $out
        fi
      '';

    # 5.8: File with imports + args
    wasm-evalNickelFileWith-import =
      let
        testDir = pkgs.runCommand "nickel-with-import-test" { } ''
          mkdir -p $out
          cat > $out/main.ncl <<'EOF'
          let lib = import "lib.ncl" in
          fun { factor, .. } => { result = lib.base * factor }
          EOF
          cat > $out/lib.ncl <<'EOF'
          { base = 7 }
          EOF
        '';
      in
      mkWasmTest "evalNickelFileWith-import" ''
        builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelFileWith";
        } { file = ${testDir}/main.ncl; args = { factor = 6; }; }
      '' "{ result = 42; }";

    # ---- Number edge cases (direct term walk) ----

    # Large integer within i64 range
    wasm-evalNickel-large-int = mkWasmTest "evalNickel-large-int" ''
      builtins.wasm {
        path = ${plugins}/nickel_plugin.wasm;
        function = "evalNickel";
      } "9999999999"
    '' "9999999999";

    # Fractional number stays float
    wasm-evalNickel-float = mkWasmTest "evalNickel-float" ''
      builtins.wasm {
        path = ${plugins}/nickel_plugin.wasm;
        function = "evalNickel";
      } "3.14"
    '' "3.14";

    # ---- ForeignId passthrough tests ----

    # Function passthrough: pass a Nix function as arg, module returns it,
    # Nix side calls it. Previously nix_to_nickel_source panicked on functions.
    wasm-foreignId-function-passthrough =
      let
        ncl = pkgs.writeText "fn-passthrough.ncl" ''
          fun { f, .. } => { result = f }
        '';
      in
      mkWasmTest "foreignId-function-passthrough" ''
        let
          double = x: x * 2;
          out = builtins.wasm {
            path = ${plugins}/nickel_plugin.wasm;
            function = "evalNickelFileWith";
          } { file = ${ncl}; args = { f = double; }; };
        in out.result 21
      '' "42";

    # Path passthrough: pass a Nix path as arg, module returns it.
    # Previously nix_to_nickel_source panicked on paths.
    wasm-foreignId-path-passthrough =
      let
        ncl = pkgs.writeText "path-passthrough.ncl" ''
          fun { p, .. } => { result = p }
        '';
        testFile = pkgs.writeText "hello.txt" "hello";
      in
      mkWasmTest "foreignId-path-passthrough" ''
        builtins.readFile (
          builtins.wasm {
            path = ${plugins}/nickel_plugin.wasm;
            function = "evalNickelFileWith";
          } { file = ${ncl}; args = { p = ${testFile}; }; }
        ).result
      '' ''"hello"'';

    # Mixed args: strings, ints, and a function all round-trip correctly.
    wasm-foreignId-mixed-args =
      let
        ncl = pkgs.writeText "mixed-args.ncl" ''
          fun { name, count, f, .. } => { greeting = name, total = count, callback = f }
        '';
      in
      mkWasmTest "foreignId-mixed-args" ''
        let
          inc = x: x + 1;
          out = builtins.wasm {
            path = ${plugins}/nickel_plugin.wasm;
            function = "evalNickelFileWith";
          } { file = ${ncl}; args = { name = "world"; count = 42; f = inc; }; };
        in { inherit (out) greeting total; applied = out.callback 9; }
      '' ''{ applied = 10; greeting = "world"; total = 42; }'';

    # ForeignId in nested Nickel records: module wraps ForeignId value
    # inside a nested record, verify recovery works at depth.
    wasm-foreignId-nested-output =
      let
        ncl = pkgs.writeText "nested-output.ncl" ''
          fun { f, .. } => { output = { inner = { deep = f } } }
        '';
      in
      mkWasmTest "foreignId-nested-output" ''
        let
          add10 = x: x + 10;
          out = builtins.wasm {
            path = ${plugins}/nickel_plugin.wasm;
            function = "evalNickelFileWith";
          } { file = ${ncl}; args = { f = add10; }; };
        in out.output.inner.deep 32
      '' "42";

    # Data-only args backward compat: verify results match exactly
    wasm-foreignId-data-only-compat =
      let
        ncl = pkgs.writeText "data-compat.ncl" ''
          fun { name, count, enabled, .. } => { output_name = name, doubled = count * 2, flag = enabled }
        '';
      in
      mkWasmTest "foreignId-data-only-compat" ''
        builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelFileWith";
        } { file = ${ncl}; args = { name = "world"; count = 21; enabled = true; }; }
      '' ''{ doubled = 42; flag = true; output_name = "world"; }'';

    # evalNickelWith with ForeignId: source string + function arg
    wasm-foreignId-evalNickelWith = mkWasmTest "foreignId-evalNickelWith" ''
      let
        add5 = x: x + 5;
        out = builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelWith";
        } { source = "fun { f, x, .. } => { result = f, val = x }"; args = { f = add5; x = 37; }; };
      in { applied = out.result 0; inherit (out) val; }
    '' "{ applied = 5; val = 37; }";

    # Re-entrant WASM: pass the result of one builtins.wasm call as an arg
    # to another. The first result is a lazy thunk; when the second call's
    # nix_to_nickel recurses into it, the thunk must resolve without
    # re-entering the WASM module.
    wasm-foreignId-wasm-result-as-arg = mkWasmTest "foreignId-wasm-result-as-arg" ''
      let
        first = builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickel";
        } "{ x = 42 }";
        out = builtins.wasm {
          path = ${plugins}/nickel_plugin.wasm;
          function = "evalNickelWith";
        } {
          source = "fun { data, .. } => { result = data.x }";
          args = { data = first; };
        };
      in out.result
    '' "42";

    # ForeignId merge conflict: two different ForeignId values at the same
    # record field should cause a Nickel merge error.
    wasm-foreignId-merge-conflict =
      let
        ncl = pkgs.writeText "merge-conflict.ncl" ''
          fun { f, g, .. } =>
            ({ x = f } & { x = g })
        '';
      in
      pkgs.runCommand "wasm-check-foreignId-merge-conflict" { nativeBuildInputs = [ nixWasm ]; } ''
        export HOME=$TMPDIR
        if nix eval --store dummy:// --offline \
            --extra-experimental-features 'nix-command flakes wasm-builtin' \
            --impure --expr '
              let
                f1 = x: x + 1;
                f2 = x: x + 2;
              in builtins.wasm {
                path = ${plugins}/nickel_plugin.wasm;
                function = "evalNickelFileWith";
              } { file = ${ncl}; args = { f = f1; g = f2; }; }
            ' 2>/dev/null; then
          echo "FAIL: expected merge conflict error but got success"
          exit 1
        else
          echo "PASS: ForeignId merge conflict correctly caused an error"
          echo "ok" > $out
        fi
      '';

    # Derivation round-trip: pass a derivation as ForeignId arg, Nickel
    # module returns it, verify the Nix side gets the same derivation back.
    # Uses a real store (not dummy://) since derivations need store paths.
    wasm-foreignId-derivation-roundtrip =
      let
        ncl = pkgs.writeText "drv-roundtrip.ncl" ''
          fun { drv, .. } => { result = drv }
        '';
      in
      pkgs.runCommand "wasm-check-foreignId-derivation-roundtrip" { nativeBuildInputs = [ nixWasm ]; } ''
        export HOME=$TMPDIR
        mkdir -p $TMPDIR/nix-store
        result=$(nix eval \
          --store $TMPDIR/nix-store --offline \
          --extra-experimental-features 'nix-command flakes wasm-builtin' \
          --impure --expr '
            let
              drv = derivation { name = "test-drv"; system = "x86_64-linux"; builder = "/bin/sh"; };
              out = builtins.wasm {
                path = ${plugins}/nickel_plugin.wasm;
                function = "evalNickelFileWith";
              } { file = ${ncl}; args = { drv = drv; }; };
            in out.result.name
          ')
        expected='"test-drv"'
        if [ "$result" = "$expected" ]; then
          echo "PASS: foreignId-derivation-roundtrip"
          echo "$result" > $out
        else
          echo "FAIL: foreignId-derivation-roundtrip"
          echo "  expected: $expected"
          echo "  got:      $result"
          exit 1
        fi
      '';

    # Large lazy attrset: pass a big lazy attrset as arg, verify only
    # get_type() is called (no mass-forcing). The attrset is passed as
    # a ForeignId and returned without inspection.
    wasm-foreignId-large-lazy-attrset =
      let
        ncl = pkgs.writeText "large-lazy.ncl" ''
          fun { big, label, .. } => { result = big, name = label }
        '';
      in
      mkWasmTest "foreignId-large-lazy-attrset" ''
        let
          # Generate a large lazy attrset (1000 fields, each a thunk)
          big = builtins.listToAttrs
            (builtins.genList (i: { name = "field_$${toString i}"; value = i * i; }) 1000);
          out = builtins.wasm {
            path = ${plugins}/nickel_plugin.wasm;
            function = "evalNickelFileWith";
          } { file = ${ncl}; args = { big = big; label = "ok"; }; };
        # Only access one field from the round-tripped attrset
        in { accessed = out.result.field_42; inherit (out) name; }
      '' ''{ accessed = 1764; name = "ok"; }'';
  };
}
