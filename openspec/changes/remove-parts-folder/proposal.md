## Why

The `parts/` directory is a leftover from the flake-parts era. When the flake migrated to adios-flake with `flake-outputs/` as the module layer, `parts/` stayed behind as an implementation detail. Every `flake-outputs/*.nix` file is a thin wrapper that imports from `parts/`, creating a two-directory indirection for no benefit. 10 of 17 parts files are 4-line `callPackage` one-liners.

## What Changes

- Inline the 13 trivial tool parts (4–9 lines each) directly into `flake-outputs/tools.nix`
- Move the 3 check/test parts (`machine-checks.nix`, `vars-checks.nix`, `vm-tests.nix`) into `flake-outputs/` as private helpers
- Inline `dev-env.nix` content directly into `flake-outputs/dev-env.nix` (eliminating the pass-through wrapper)
- Delete `parts/` directory entirely
- Update `CLAUDE.md` project structure docs to remove `parts/` references

## Capabilities

### New Capabilities

_None — this is a structural refactor with no new functionality._

### Modified Capabilities

_None — no spec-level behavior changes, only file layout._

## Impact

- **Files removed**: All 17 files in `parts/`
- **Files modified**: `flake-outputs/tools.nix`, `flake-outputs/checks.nix`, `flake-outputs/dev-env.nix`, `CLAUDE.md`
- **Zero behavior change**: All flake outputs (packages, checks, devShells, formatter) remain identical
- **No dependency changes**: Same inputs, same packages
