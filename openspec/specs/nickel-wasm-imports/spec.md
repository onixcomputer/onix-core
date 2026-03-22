## ADDED Requirements

### Requirement: WasmHostIO implements SourceIO via nix-wasm ABI
The `nickel-plugin` crate SHALL define a `WasmHostIO` struct that implements `SourceIO` by routing through the nix-wasm host ABI. `current_dir()` SHALL return the parent directory of the input file path. `read_to_string()` SHALL use `Value::make_path()` + `Value::read_file()`. `metadata_timestamp()` SHALL return `UNIX_EPOCH`.

#### Scenario: current_dir returns parent of input file
- **WHEN** `WasmHostIO` is constructed with a Nix path `/nix/store/abc-source/config/main.ncl`
- **THEN** `current_dir()` returns `/nix/store/abc-source/config`

#### Scenario: read_to_string reads via host ABI
- **WHEN** `WasmHostIO::read_to_string("/nix/store/abc-source/config/lib.ncl")` is called
- **THEN** the file content is read through the nix-wasm `read_file` host function, not `std::fs`

#### Scenario: metadata_timestamp returns epoch
- **WHEN** `WasmHostIO::metadata_timestamp()` is called for any path
- **THEN** it returns `SystemTime::UNIX_EPOCH`

### Requirement: evalNickelFile resolves relative imports
The `evalNickelFile` function SHALL support Nickel `import "relative.ncl"` statements. Imports MUST be resolved relative to the importing file's parent directory using the host ABI's `make_path` for path construction and `read_file` for content retrieval.

#### Scenario: Single relative import
- **WHEN** `evalNickelFile` is called on `main.ncl` containing `import "lib.ncl"` and `lib.ncl` exists as a sibling file
- **THEN** `lib.ncl` is loaded via the host ABI and the combined result is returned as a Nix value

#### Scenario: Nested imports
- **WHEN** `main.ncl` imports `sub/a.ncl` which imports `../b.ncl`
- **THEN** all files are resolved through the host ABI and the evaluation succeeds

#### Scenario: Missing import file
- **WHEN** `main.ncl` imports a file that does not exist
- **THEN** Nix evaluation fails with an error message containing the missing file path

### Requirement: evalNickelFile passes SourceIO to SourceCache
The `evalNickelFile` function SHALL construct a `Program` with a `SourceCache` that uses `WasmHostIO` as its IO provider. The base path for `WasmHostIO` SHALL be derived from the Nix path argument.

#### Scenario: Program uses WasmHostIO
- **WHEN** `evalNickelFile` is called
- **THEN** the `Program`'s `SourceCache` uses `WasmHostIO` for all file operations during import resolution

### Requirement: Flake checks validate import resolution
The `_wasm-checks.nix` file SHALL include checks that test multi-file Nickel evaluation through the WASM plugin.

#### Scenario: Import check passes
- **WHEN** `nix flake check` runs with a test that evaluates a `.ncl` file importing another `.ncl` file (both created via `pkgs.writeText` or `pkgs.runCommand`)
- **THEN** the check passes and returns the merged Nickel evaluation result

### Requirement: evalNickelFile doc updated to reflect import support
The `lib/wasm.nix` comment for `evalNickelFile` SHALL be updated to document that relative imports are supported.

#### Scenario: Documentation is accurate
- **WHEN** the `evalNickelFile` comment in `lib/wasm.nix` is read
- **THEN** it states that relative `import` statements are supported and resolved via the host ABI
