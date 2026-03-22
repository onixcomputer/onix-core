## Why

Nickel's contract system catches structural and type errors that Nix's type system cannot express. Right now the only way to use Nickel contracts is to write the entire config in Nickel. Most NixOS configuration is written in Nix and should stay that way — but complex data shapes (Traefik routes, Prometheus rules, backup policies) benefit from contract validation. There's no way to take a Nix value and run a Nickel contract against it.

## What Changes

- Add a `validateNickel` exported function to `nickel-plugin` that takes a Nix attrset with `contract` (path to a `.ncl` file exporting a contract) and `value` (a Nix value to validate)
- The Nix value is converted to a Nickel value, the contract is applied, and either the original Nix value is returned (pass) or Nix evaluation fails with the contract violation message
- Expose `validateNickel` wrapper in `lib/wasm.nix`
- Add flake checks for passing and failing validation scenarios

## Capabilities

### New Capabilities
- `nickel-validate`: Applying Nickel contracts to Nix values as a pure validation layer, converting Nix values to Nickel, applying a contract loaded from a `.ncl` file, and returning the value or propagating the contract error

### Modified Capabilities

## Impact

- `wasm-plugins/nickel-plugin/src/lib.rs` — new exported function, Nix-to-Nickel value conversion (shared with `nickel-eval-args` change), contract application logic
- `wasm-plugins/nix-wasm-rust/` — same accessor requirements as `nickel-eval-args`
- `lib/wasm.nix` — new `validateNickel` wrapper
- `flake-outputs/_wasm-checks.nix` — new test cases for pass/fail validation
- No changes to existing functions (no breaking changes)
