## Why

`evalNickelFile` takes a path and nothing else. Every `.ncl` config evaluated via the wasm plugin is static — it can't adapt based on the machine it's being evaluated for, the number of CPU cores, available RAM, or any other Nix-side value. The only workaround is string interpolation into `evalNickel`, which is fragile and loses Nickel's contract checking on the interpolated values.

## What Changes

- Add a new `evalNickelFileWith` exported function to `nickel-plugin` that accepts a Nix attrset containing a file path and an arguments record
- The arguments attrset is converted from Nix values to Nickel values and injected into the Nickel program as a top-level binding that the `.ncl` file can destructure
- Add a corresponding `evalNickelWith` for inline string evaluation with arguments
- Expose `evalNickelFileWith` and `evalNickelWith` wrappers in `lib/wasm.nix`
- Add flake checks covering argument passing for all supported types (string, int, float, bool, null, list, attrset, nested)

## Capabilities

### New Capabilities
- `nickel-eval-args`: Passing Nix values as arguments into Nickel evaluation, converting Nix attrsets/lists/scalars to Nickel records/arrays/scalars, and making them available to the Nickel program

### Modified Capabilities
- `nickel-eval`: The existing `evalNickel` capability is extended with a `With` variant that accepts arguments

## Impact

- `wasm-plugins/nickel-plugin/src/lib.rs` — new exported functions and Nix-to-Nickel value conversion
- `wasm-plugins/nix-wasm-rust/` — may need `get_attr`, `get_list_length`, `get_list_elem` or similar accessors if not already exposed
- `lib/wasm.nix` — new wrapper functions
- `flake-outputs/_wasm-checks.nix` — new test cases
- Existing `evalNickel` / `evalNickelFile` are unchanged (no breaking changes)
