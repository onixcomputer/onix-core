## ADDED Requirements

### Requirement: Evaluate Nickel source string to Nix value
The system SHALL provide an `evalNickel` function that takes a Nickel source string and returns a native Nix value. The function MUST be callable from Nix via `builtins.wasm` and MUST return the fully-evaluated Nickel result as a Nix attrset, list, string, number, bool, or null.

#### Scenario: Evaluate a simple Nickel record
- **WHEN** `wasm.evalNickel '{ x = 1, y = "hello" }'` is called
- **THEN** the result is a Nix attrset `{ x = 1; y = "hello"; }`

#### Scenario: Evaluate a Nickel list
- **WHEN** `wasm.evalNickel '[1, 2, 3]'` is called
- **THEN** the result is a Nix list `[ 1 2 3 ]`

#### Scenario: Evaluate nested Nickel structures
- **WHEN** `wasm.evalNickel '{ a = { b = [true, null, 3.14] } }'` is called
- **THEN** the result is a nested Nix attrset `{ a = { b = [ true null 3.14 ]; }; }`

#### Scenario: Evaluate Nickel with let bindings and functions
- **WHEN** `wasm.evalNickel 'let double = fun x => x * 2 in { result = double 21 }'` is called
- **THEN** the result is `{ result = 42; }`

### Requirement: Nickel evaluation errors produce Nix errors
The system SHALL propagate Nickel parse errors, type errors, and contract violations as Nix evaluation errors with descriptive messages. The WASM plugin MUST call the host `panic` function with the Nickel error text.

#### Scenario: Nickel syntax error
- **WHEN** `wasm.evalNickel '{ x = }'` is called (invalid syntax)
- **THEN** Nix evaluation fails with an error message containing the Nickel parse error

#### Scenario: Nickel type error
- **WHEN** `wasm.evalNickel '1 + "hello"'` is called (type mismatch)
- **THEN** Nix evaluation fails with an error message describing the type error

#### Scenario: Nickel contract violation
- **WHEN** a Nickel expression applies a `Number` contract to a string value
- **THEN** Nix evaluation fails with an error message describing the contract violation

### Requirement: Nickel stdlib is available
The system SHALL make the full Nickel standard library available during evaluation. Nickel code MUST be able to use `std.array.map`, `std.string.uppercase`, and other stdlib functions without explicit imports.

#### Scenario: Use stdlib function
- **WHEN** `wasm.evalNickel '{ result = std.array.map (fun x => x * 2) [1, 2, 3] }'` is called
- **THEN** the result is `{ result = [ 2 4 6 ]; }`

### Requirement: WASM plugin exports correct function signature
The `nickel-plugin` WASM module SHALL export a function named `evalNickel` with the signature `extern "C" fn(Value) -> Value`, following the `nix-wasm-rust` ABI. The module SHALL also export `nix_wasm_init_v1` for panic hook initialization.

#### Scenario: Plugin loads and executes via builtins.wasm
- **WHEN** `builtins.wasm { path = "${plugins}/nickel_plugin.wasm"; function = "evalNickel"; } "42"` is called
- **THEN** the result is the Nix integer `42`

### Requirement: Nix wrapper function in lib/wasm.nix
The `lib/wasm.nix` module SHALL expose `evalNickel` as a function that wraps the `builtins.wasm` call. The wrapper MUST accept a single string argument (Nickel source) and return the evaluated Nix value.

#### Scenario: Wrapper function is accessible
- **WHEN** `let wasm = import ./lib/wasm.nix { inherit plugins; }; in wasm.evalNickel "42"` is evaluated
- **THEN** the result is `42`

### Requirement: Flake check validates Nickel evaluation
The `_wasm-checks.nix` file SHALL include check derivations that test `evalNickel` end-to-end using the wasm-enabled Nix binary. Checks MUST cover: simple values, records, lists, nested structures, and error cases.

#### Scenario: Checks pass in nix flake check
- **WHEN** `nix flake check` runs (or `build` targets the check derivation)
- **THEN** all `wasm-evalNickel-*` checks pass
