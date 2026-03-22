## 1. Workspace Setup

- [x] 1.1 Add `nickel-plugin` crate directory under `wasm-plugins/` with `Cargo.toml` depending on `nix-wasm-rust` (path dep) and `nickel-lang-core` (pinned version, `default-features = false`) and `serde_json`
- [x] 1.2 Add `nickel-plugin` to `wasm-plugins/Cargo.toml` workspace members list
- [x] 1.3 Run `cargo update -p nickel-lang-core` in `wasm-plugins/` to generate lock entries and verify the dependency tree resolves for `wasm32-unknown-unknown`
- [x] 1.4 Add `nickel_plugin.wasm` to the install phase case statement in `wasm-plugins/default.nix`

## 2. Phase 1 — evalNickel (String Input)

- [x] 2.1 Create `wasm-plugins/nickel-plugin/src/lib.rs` with `nix_wasm_init_v1` export and `json_to_nix` helper that converts `serde_json::Value` → `nix_wasm_rust::Value`
- [x] 2.2 Implement `evalNickel` exported function: receive `Value` string arg, construct `Program::new_from_source`, call `eval_full_for_export`, serialize to JSON, convert to Nix values via `json_to_nix`
- [x] 2.3 Verify the crate compiles to `wasm32-unknown-unknown` with `cargo build --release --target wasm32-unknown-unknown -p nickel-plugin`
- [x] 2.4 Verify `wasm-opt -Oz --enable-bulk-memory` succeeds on the output and check binary size

## 3. Nix Integration — evalNickel

- [x] 3.1 Add `evalNickel` wrapper function to `lib/wasm.nix` that calls `builtins.wasm { path = "${plugins}/nickel_plugin.wasm"; function = "evalNickel"; }`
- [x] 3.2 Add flake checks to `flake-outputs/_wasm-checks.nix`: simple int (`"42"`), record (`'{ x = 1, y = "hello" }'`), list (`'[1, 2, 3]'`), nested structures, and let-binding with function application
- [x] 3.3 Build the full `wasm-plugins` package with `nix build .#wasm-plugins` and verify `nickel_plugin.wasm` appears in output
- [x] 3.4 Run the new wasm checks and confirm all pass

## 4. Phase 2 — evalNickelFile (Path Input)

- [x] 4.1 Implement `evalNickelFile` exported function in `nickel-plugin/src/lib.rs`: receive `Value` path arg, call `Value::read_file()` to get `.ncl` content, feed to Nickel evaluator as string source, return Nix values
- [x] 4.2 Implement host-ABI-backed import resolver — resolved via vendored nickel-lang-core with SourceIO trait (see nickel-wasm-io-trait change)
- [x] 4.3 Handle import resolution edge cases — resolved via vendored nickel-lang-core with SourceIO trait (see nickel-wasm-io-trait change)

## 5. Nix Integration — evalNickelFile

- [x] 5.1 Add `evalNickelFile` wrapper function to `lib/wasm.nix`
- [x] 5.2 Add flake checks to `_wasm-checks.nix`: single-file eval (write a `.ncl` file via `pkgs.writeText`), stdlib usage test (import test deferred per 4.2)
- [x] 5.3 Run all wasm checks (`nix flake check` or targeted build) and confirm pass

## 6. Error Handling and Polish

- [x] 6.1 Test and verify Nickel parse errors surface as readable Nix eval errors (not raw panics)
- [x] 6.2 Test and verify Nickel type errors and contract violations produce useful error messages
- [x] 6.3 Add a negative test check to `_wasm-checks.nix` that confirms a malformed Nickel expression causes a build failure (use `pkgs.runCommand` that expects failure)
- [x] 6.4 Document the new `evalNickel` and `evalNickelFile` functions in `lib/wasm.nix` comments
