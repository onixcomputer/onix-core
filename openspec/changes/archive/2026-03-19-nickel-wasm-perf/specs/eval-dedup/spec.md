## ADDED Requirements

### Requirement: Theme NCL files evaluated once across all machines

Each theme `.ncl` file in `inventory/home-profiles/shared/desktop/themes/` SHALL be evaluated at most once during a full fleet eval, regardless of how many machines use the noctalia/desktop profile.

#### Scenario: Multiple desktop machines share theme evaluation
- **WHEN** 3 machines load the noctalia profile (which imports `theme.nix`)
- **THEN** each theme `.ncl` file is evaluated via `wasm.evalNickelFile` exactly once, not once per machine

#### Scenario: theme.nix consumes pre-evaluated data
- **WHEN** `theme.nix` needs `activeThemeData` for a specific machine
- **THEN** it reads from a shared `allThemeData` module argument instead of calling `wasm.evalNickelFile` directly

#### Scenario: theme-data.nix consumes pre-evaluated data
- **WHEN** `theme-data.nix` needs `activeThemeData` for a server machine (where `theme.nix` is not loaded)
- **THEN** it reads from the shared `allThemeData` module argument instead of calling `wasm.evalNickelFile` directly

### Requirement: machines.ncl evaluated once across all modules

The `machines.ncl` file SHALL be evaluated at most once during a full fleet eval. Tag modules that need the machines data SHALL consume the pre-evaluated result via a module argument.

#### Scenario: remote-builders.nix consumes pre-evaluated machines data
- **WHEN** `remote-builders.nix` needs the machines attrset
- **THEN** it reads from a shared module argument instead of calling `wasm.evalNickelFile ../core/machines.ncl`

#### Scenario: core/default.nix is the single evaluation site
- **WHEN** the flake evaluates `inventory/core/default.nix`
- **THEN** `machines.ncl` is evaluated once and the result is made available to all consuming modules

### Requirement: Deduplicated evaluations produce identical data

Modules consuming pre-evaluated NCL data SHALL receive the same values they would have received from direct `wasm.evalNickelFile` calls.

#### Scenario: Theme data matches direct evaluation
- **WHEN** `theme.nix` reads from the shared `allThemeData` argument
- **THEN** the data for each theme is identical to what `wasm.evalNickelFile (themesDir + "/${themeName}.ncl")` would return

#### Scenario: Machines data matches direct evaluation
- **WHEN** `remote-builders.nix` reads from the shared machines argument
- **THEN** the machines attrset is identical to what `(wasm.evalNickelFile ../core/machines.ncl).machines` would return
