## ADDED Requirements

### Requirement: User source evaluation skips typechecking

The Nickel plugin SHALL skip the typechecking phase when evaluating user source (both file-based and string-based inputs). Only parsing, compilation, transformation, and evaluation SHALL be performed.

#### Scenario: evalNickelFile does not typecheck
- **WHEN** `evalNickelFile` is called on a `.ncl` file
- **THEN** the file is parsed, compiled, transformed, and evaluated without running `typecheck()`

#### Scenario: evalNickelFileWith does not typecheck
- **WHEN** `evalNickelFileWith` is called with a `.ncl` file and args
- **THEN** the combined source is parsed, compiled, transformed, and evaluated without running `typecheck()`

#### Scenario: evalNickel string input does not typecheck
- **WHEN** `evalNickel` is called with a Nickel source string
- **THEN** the source is parsed, compiled, transformed, and evaluated without running `typecheck()`

### Requirement: Type errors surface as eval-time failures

When typechecking is skipped, type-related errors that would have been caught by the typechecker SHALL surface as evaluation-time errors with Nickel's standard error messages.

#### Scenario: Contract violation produces eval error
- **WHEN** a `.ncl` file applies a contract (e.g., `x | Number`) and the value violates it at eval time
- **THEN** the plugin panics with a Nickel eval error containing the contract violation details

#### Scenario: Well-typed programs produce identical results
- **WHEN** a `.ncl` file that passes typechecking is evaluated without the typechecking phase
- **THEN** the returned Nix value is identical to what evaluation with typechecking would produce
