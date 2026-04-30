# Nickel Direct Walk Specification

## Purpose

This specification records requirements synced from OpenSpec change `nickel-direct-term-walk`.

## Requirements

<!-- synced from openspec change: nickel-direct-term-walk -->
## ADDED Requirements

### Requirement: Direct RichTerm to Nix value conversion
The system SHALL provide a `richterm_to_nix` function that converts a fully-evaluated Nickel `RichTerm` directly to a `nix_wasm_rust::Value` without intermediate JSON serialization. The function MUST handle `Term::Null`, `Term::Bool`, `Term::Num`, `Term::Str`, `Term::Array`, `Term::Record`, and `Term::RecRecord` variants.

#### Scenario: Convert Nickel null
- **WHEN** `richterm_to_nix` receives a `Term::Null`
- **THEN** it returns `Value::make_null()`

#### Scenario: Convert Nickel bool
- **WHEN** `richterm_to_nix` receives `Term::Bool(true)`
- **THEN** it returns `Value::make_bool(true)`

#### Scenario: Convert Nickel integer number
- **WHEN** `richterm_to_nix` receives `Term::Num` with value `42` (no fractional part, fits in i64)
- **THEN** it returns `Value::make_int(42)`

#### Scenario: Convert Nickel float number
- **WHEN** `richterm_to_nix` receives `Term::Num` with value `3.14`
- **THEN** it returns `Value::make_float(3.14)`

#### Scenario: Convert Nickel string
- **WHEN** `richterm_to_nix` receives `Term::Str("hello")`
- **THEN** it returns `Value::make_string("hello")`

#### Scenario: Convert Nickel array
- **WHEN** `richterm_to_nix` receives `Term::Array` containing `[1, "two", true]`
- **THEN** it returns `Value::make_list` with the recursively converted elements

#### Scenario: Convert Nickel record
- **WHEN** `richterm_to_nix` receives `Term::Record` with fields `{ x = 1, y = "hello" }`
- **THEN** it returns `Value::make_attrset` with the recursively converted fields

#### Scenario: Convert nested structures
- **WHEN** `richterm_to_nix` receives a record containing arrays containing records
- **THEN** all levels are recursively converted to the corresponding Nix types

#### Scenario: Unexpected term variant
- **WHEN** `richterm_to_nix` receives an unhandled `Term` variant (e.g., `Term::Var`, `Term::Fun`)
- **THEN** it calls `nix_wasm_rust::panic` with a message including the term's debug representation

### Requirement: Number conversion preserves int/float distinction
Nickel uses a single `Number` type. The conversion SHALL emit `Value::make_int` when the number has no fractional part and its absolute value fits in `i64`. Otherwise it SHALL emit `Value::make_float`. This MUST match the behavior of the previous JSON-based conversion path.

#### Scenario: Zero is int
- **WHEN** the Nickel number is `0`
- **THEN** the result is `Value::make_int(0)`

#### Scenario: Negative integer
- **WHEN** the Nickel number is `-5`
- **THEN** the result is `Value::make_int(-5)`

#### Scenario: Small fraction is float
- **WHEN** the Nickel number is `0.5`
- **THEN** the result is `Value::make_float(0.5)`

#### Scenario: Large integer within i64 range
- **WHEN** the Nickel number is `9999999999` (fits in i64)
- **THEN** the result is `Value::make_int(9999999999)`

### Requirement: serde_json dependency is removed
The `nickel-plugin` crate SHALL NOT depend on `serde_json` after this change. All JSON serialization and parsing code (`json_to_nix`, `serialize::to_string(ExportFormat::Json, ...)`, `serde_json::from_str`) SHALL be removed from `lib.rs`.

#### Scenario: Cargo.toml has no serde_json
- **WHEN** `wasm-plugins/nickel-plugin/Cargo.toml` is inspected
- **THEN** `serde_json` does not appear in `[dependencies]`

#### Scenario: No JSON imports in lib.rs
- **WHEN** `wasm-plugins/nickel-plugin/src/lib.rs` is inspected
- **THEN** there are no `use serde_json` statements and no `json_to_nix` function
