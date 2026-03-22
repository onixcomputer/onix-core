## ADDED Requirements

### Requirement: Evaluate Nickel file from Nix path
The system SHALL provide an `evalNickelFile` function that takes a Nix path pointing to a `.ncl` file, reads it via the host WASM ABI (`read_file`), evaluates the Nickel source, and returns a native Nix value.

#### Scenario: Evaluate a .ncl file
- **WHEN** `wasm.evalNickelFile ./config.ncl` is called where `config.ncl` contains `{ port = 8080, host = "localhost" }`
- **THEN** the result is a Nix attrset `{ port = 8080; host = "localhost"; }`

#### Scenario: File path is a Nix store path
- **WHEN** `wasm.evalNickelFile "${pkgs.writeText "test.ncl" "42"}"` is called (a store path)
- **THEN** the result is the Nix integer `42`

### Requirement: Resolve relative Nickel imports via host ABI
The system SHALL support Nickel's `import "relative/path.ncl"` syntax by resolving paths relative to the importing file's location. Path resolution MUST use the host's `make_path(base, rel)` function and file reading MUST use the host's `read_file` function. No `std::fs` calls SHALL be made from within the WASM module.

#### Scenario: Single relative import
- **WHEN** `wasm.evalNickelFile ./main.ncl` is called where `main.ncl` contains `let lib = import "lib.ncl" in { result = lib.value }` and `lib.ncl` contains `{ value = 42 }`
- **THEN** the result is `{ result = 42; }`

#### Scenario: Nested imports
- **WHEN** `wasm.evalNickelFile ./main.ncl` is called where `main.ncl` imports `sub/a.ncl` which imports `../b.ncl`
- **THEN** all imports resolve correctly through the host ABI and the result is the fully-evaluated Nickel expression

#### Scenario: Missing import file
- **WHEN** `wasm.evalNickelFile ./main.ncl` is called and `main.ncl` imports a file that does not exist in the source tree
- **THEN** Nix evaluation fails with an error message indicating the missing import path

### Requirement: WASM plugin exports evalNickelFile function
The `nickel-plugin` WASM module SHALL export a function named `evalNickelFile` with the signature `extern "C" fn(Value) -> Value`. The `Value` argument MUST be a Nix path. The function SHALL read the file content using `Value::read_file()` and evaluate it.

#### Scenario: Plugin reads file via host ABI
- **WHEN** `builtins.wasm { path = "${plugins}/nickel_plugin.wasm"; function = "evalNickelFile"; } ./test.ncl` is called
- **THEN** the plugin reads the file content through the host-provided `read_file` FFI function (not `std::fs`)

### Requirement: Nix wrapper function for file evaluation
The `lib/wasm.nix` module SHALL expose `evalNickelFile` as a function that wraps the `builtins.wasm` call. The wrapper MUST accept a single path argument and return the evaluated Nix value.

#### Scenario: Wrapper function is accessible
- **WHEN** `let wasm = import ./lib/wasm.nix { inherit plugins; }; in wasm.evalNickelFile ./config.ncl` is evaluated
- **THEN** the result matches the evaluated Nickel content of `config.ncl`

### Requirement: Flake checks validate file-based evaluation
The `_wasm-checks.nix` file SHALL include check derivations for `evalNickelFile` covering: single-file evaluation, relative imports, and missing file errors.

#### Scenario: File evaluation checks pass
- **WHEN** `nix flake check` runs
- **THEN** all `wasm-evalNickelFile-*` checks pass
