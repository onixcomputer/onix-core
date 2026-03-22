## MODIFIED Requirements

### Requirement: Evaluate Nickel source string to Nix value
The system SHALL provide an `evalNickel` function that takes a Nickel source string and returns a native Nix value. The function MUST be callable from Nix via `builtins.wasm` and MUST return the fully-evaluated Nickel result as a Nix attrset, list, string, number, bool, or null. The system SHALL additionally provide an `evalNickelWith` variant that accepts a Nix attrset with `source` and `args` keys, applying the args to the evaluated function.

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

#### Scenario: Evaluate with arguments
- **WHEN** `wasm.evalNickelWith "fun { x, .. } => x + 1" { x = 41; }` is called
- **THEN** the result is the Nix int `42`
