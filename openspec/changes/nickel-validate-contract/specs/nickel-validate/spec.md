## ADDED Requirements

### Requirement: Validate a Nix value against a Nickel contract
The system SHALL provide a `validateNickel` exported function that takes a Nix attrset with keys `contract` (a Nix path to a `.ncl` file) and `value` (any Nix data value). The contract file MUST evaluate to a Nickel record with contract annotations. The Nix value SHALL be converted to a Nickel term, merged with the contract, and fully evaluated to trigger contract checking. On success, the original Nix `value` SHALL be returned unchanged.

#### Scenario: Valid value passes contract
- **WHEN** `validateNickel { contract = ./schema.ncl; value = { port = 8080; host = "localhost"; }; }` is called and `schema.ncl` contains `{ port | Number, host | String }`
- **THEN** the original Nix attrset `{ port = 8080; host = "localhost"; }` is returned

#### Scenario: Value with extra fields passes open contract
- **WHEN** the contract is `{ port | Number, .. }` and the value is `{ port = 80; extra = true; }`
- **THEN** the original Nix value is returned (open record contract allows extra fields)

#### Scenario: Nested record validation
- **WHEN** the contract is `{ http | { routers | { _ : { rule | String } } } }` and the value is `{ http.routers.main.rule = "Host(example.com)"; }`
- **THEN** the original Nix value is returned

#### Scenario: List validation
- **WHEN** the contract is `{ ports | Array Number }` and the value is `{ ports = [80, 443]; }`
- **THEN** the original Nix value is returned

### Requirement: Contract violations produce Nix errors
The system SHALL propagate Nickel contract violation errors as Nix evaluation errors. The error message MUST include the contract file path, the Nickel blame message, and the field path where the violation occurred (when available).

#### Scenario: Type mismatch
- **WHEN** the contract is `{ port | Number }` and the value is `{ port = "eighty"; }`
- **THEN** Nix evaluation fails with an error message indicating a contract violation on field `port`

#### Scenario: Missing required field
- **WHEN** the contract is `{ port | Number, host | String }` and the value is `{ port = 80; }`
- **THEN** Nix evaluation fails with an error message indicating the missing field `host`

#### Scenario: Custom contract violation
- **WHEN** the contract defines a custom predicate `let Port = std.contract.from_predicate (fun x => x > 0 && x < 65536) in { port | Port }` and the value is `{ port = 99999; }`
- **THEN** Nix evaluation fails with a contract violation error

#### Scenario: Nested field violation
- **WHEN** the contract is `{ http | { port | Number } }` and the value is `{ http.port = "bad"; }`
- **THEN** the error message includes the field path `http.port`

### Requirement: Original Nix value is returned on success
The `validateNickel` function SHALL return the original Nix `Value` from the `value` key of the input attrset, NOT a round-tripped value. The Nix-to-Nickel conversion is used only for contract checking. This preserves Nix string contexts, derivation references, and other Nix-specific value properties.

#### Scenario: String context preservation
- **WHEN** `validateNickel` is called with a value containing Nix string interpolations (string context)
- **THEN** the returned value retains the original string contexts

#### Scenario: Return value is identity
- **WHEN** `validateNickel` succeeds
- **THEN** the returned value is the exact same Nix `Value` object as the input, not a reconstruction

### Requirement: Contract file is evaluated with import support
The contract `.ncl` file SHALL be evaluated with the same `WasmHostIO`-backed import resolution as `evalNickelFile`. Contract files MUST be able to use `import` to reference shared contract libraries.

#### Scenario: Contract imports shared library
- **WHEN** `schema.ncl` contains `let common = import "common-contracts.ncl" in { port | common.Port }` and `common-contracts.ncl` exists alongside it
- **THEN** the import resolves via the host ABI and the contract is applied correctly

### Requirement: Nix wrapper function in lib/wasm.nix
The `lib/wasm.nix` module SHALL expose `validateNickel` as a function taking a single attrset argument with `contract` and `value` keys. The wrapper MUST invoke `builtins.wasm` with the nickel_plugin and function name `validateNickel`.

#### Scenario: Wrapper invocation
- **WHEN** `wasm.validateNickel { contract = ./schema.ncl; value = myConfig; }` is called
- **THEN** it invokes `builtins.wasm` with the appropriate plugin path and the input attrset

### Requirement: Flake checks validate contract application
The `flake-outputs/_wasm-checks.nix` file SHALL include checks for `validateNickel` covering: successful validation, type mismatch failure, missing field failure, custom contract failure, and nested validation.

#### Scenario: Passing and failing checks
- **WHEN** `nix flake check` runs the validation checks
- **THEN** checks confirming successful validation pass, and checks confirming expected failures pass
