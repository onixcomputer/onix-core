## ADDED Requirements

### Requirement: Convert Nix values to Nickel terms
The system SHALL provide a `nix_to_nickel` function that converts a `nix_wasm_rust::Value` into a `nickel_lang_core::term::RichTerm`. The function MUST support int, float, bool, string, null, list, and attrset types. Conversion MUST be recursive for lists and attrsets.

#### Scenario: Convert Nix int to Nickel number
- **WHEN** `nix_to_nickel` is called with a Nix int value `42`
- **THEN** the result is a `Term::Num` representing `42`

#### Scenario: Convert Nix float to Nickel number
- **WHEN** `nix_to_nickel` is called with a Nix float value `3.14`
- **THEN** the result is a `Term::Num` representing `3.14`

#### Scenario: Convert Nix bool to Nickel bool
- **WHEN** `nix_to_nickel` is called with a Nix bool value `true`
- **THEN** the result is a `Term::Bool(true)`

#### Scenario: Convert Nix string to Nickel string
- **WHEN** `nix_to_nickel` is called with a Nix string `"hello"`
- **THEN** the result is a `Term::Str` containing `"hello"`

#### Scenario: Convert Nix null to Nickel null
- **WHEN** `nix_to_nickel` is called with a Nix null value
- **THEN** the result is `Term::Null`

#### Scenario: Convert Nix list to Nickel array
- **WHEN** `nix_to_nickel` is called with a Nix list `[1, "two", true]`
- **THEN** the result is a `Term::Array` containing the converted elements

#### Scenario: Convert Nix attrset to Nickel record
- **WHEN** `nix_to_nickel` is called with a Nix attrset `{ x = 1; y = "hello"; }`
- **THEN** the result is a `Term::Record` with fields `x` and `y` containing the converted values

#### Scenario: Convert nested Nix structures
- **WHEN** `nix_to_nickel` is called with `{ a = { b = [1, 2]; }; c = null; }`
- **THEN** the result is a nested `Term::Record` containing a `Term::Array` and `Term::Null`

#### Scenario: Unsupported Nix type
- **WHEN** `nix_to_nickel` is called with a Nix function or other unsupported type
- **THEN** the function calls `nix_wasm_rust::panic` with a descriptive error message

### Requirement: Evaluate Nickel file with Nix arguments
The system SHALL provide an `evalNickelFileWith` exported function that takes a Nix attrset with keys `file` (a Nix path) and `args` (a Nix attrset). The `.ncl` file MUST evaluate to a function. The converted `args` record SHALL be applied to that function. The result SHALL be fully evaluated and returned as a Nix value.

#### Scenario: File function receives arguments
- **WHEN** `evalNickelFileWith { file = ./config.ncl; args = { cores = 8; }; }` is called where `config.ncl` contains `fun { cores, .. } => { workers = cores * 2 }`
- **THEN** the result is a Nix attrset `{ workers = 16; }`

#### Scenario: File function receives nested arguments
- **WHEN** `evalNickelFileWith` is called with `args = { net = { port = 8080; }; }` and the file uses `args.net.port`
- **THEN** the nested attrset is correctly converted and accessible in Nickel

#### Scenario: File function applies contracts to arguments
- **WHEN** the `.ncl` file declares `fun { cores | Number, .. } => ...` and `args = { cores = 8; }` is passed
- **THEN** the Nickel contract is checked against the converted value and evaluation succeeds

#### Scenario: Contract violation on arguments
- **WHEN** the `.ncl` file declares `fun { cores | Number, .. } => ...` and `args = { cores = "eight"; }` is passed
- **THEN** Nix evaluation fails with a Nickel contract violation error

#### Scenario: File is not a function
- **WHEN** `evalNickelFileWith` is called and the `.ncl` file evaluates to a record (not a function)
- **THEN** a warning is emitted and the file's value is returned, ignoring args

#### Scenario: Import resolution works with arguments
- **WHEN** `evalNickelFileWith` is called on a file that uses `import "lib.ncl"`
- **THEN** import resolution works identically to `evalNickelFile`

### Requirement: Evaluate Nickel source string with arguments
The system SHALL provide an `evalNickelWith` exported function that takes a Nix attrset with keys `source` (a Nickel source string) and `args` (a Nix attrset). The source MUST evaluate to a function. The converted `args` record SHALL be applied to that function.

#### Scenario: Source function receives arguments
- **WHEN** `evalNickelWith { source = "fun { x, .. } => x + 1"; args = { x = 41; }; }` is called
- **THEN** the result is the Nix int `42`

#### Scenario: Missing required argument
- **WHEN** the source expects `{ x, y }` but only `{ x = 1; }` is passed
- **THEN** Nix evaluation fails with a Nickel error about the missing field

### Requirement: Nix wrapper functions in lib/wasm.nix
The `lib/wasm.nix` module SHALL expose `evalNickelFileWith` as a function taking `path` and `args` arguments, and `evalNickelWith` taking `source` and `args` arguments. Both MUST wrap the `builtins.wasm` call and pack the arguments into the expected attrset format.

#### Scenario: evalNickelFileWith wrapper
- **WHEN** `wasm.evalNickelFileWith ./config.ncl { cores = 8; }` is called
- **THEN** it invokes `builtins.wasm` with `{ file = ./config.ncl; args = { cores = 8; }; }`

#### Scenario: evalNickelWith wrapper
- **WHEN** `wasm.evalNickelWith "fun { x, .. } => x" { x = 1; }` is called
- **THEN** it invokes `builtins.wasm` with `{ source = "fun { x, .. } => x"; args = { x = 1; }; }`

### Requirement: Flake checks validate argument passing
The `flake-outputs/_wasm-checks.nix` file SHALL include checks for `evalNickelFileWith` and `evalNickelWith` covering: scalar arguments, nested attrsets, list arguments, contract validation on arguments, and contract violation on arguments.

#### Scenario: Check passes for valid arguments
- **WHEN** `nix flake check` runs the wasm argument-passing checks
- **THEN** all checks pass for valid argument combinations

#### Scenario: Check passes for contract violation
- **WHEN** a flake check tests that a contract violation produces an error
- **THEN** the check confirms that Nix evaluation fails with the expected error
