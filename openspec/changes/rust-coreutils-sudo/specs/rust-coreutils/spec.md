## ADDED Requirements

### Requirement: uutils-coreutils replaces GNU coreutils in PATH
All NixOS machines SHALL have `uutils-coreutils-noprefix` as the default coreutils in the system PATH. The uutils binaries (ls, cp, mv, cat, etc.) SHALL take precedence over GNU equivalents.

#### Scenario: Default coreutils is uutils
- **WHEN** a user runs `ls --version` on any NixOS machine
- **THEN** the output identifies uutils-coreutils, not GNU coreutils

#### Scenario: Common operations work
- **WHEN** a user runs standard coreutils commands (ls, cp, mv, cat, head, tail, wc, sort, uniq, mkdir, rm, chmod, chown)
- **THEN** each command behaves as expected for standard POSIX usage

### Requirement: GNU coreutils remains available as fallback
GNU coreutils SHALL remain installed on all NixOS machines so scripts depending on GNU-specific extensions can reference it explicitly.

#### Scenario: GNU coreutils accessible by full path
- **WHEN** a user needs a GNU-specific flag not supported by uutils
- **THEN** the GNU binary is available in the system closure (e.g., via `${pkgs.coreutils}/bin/<cmd>`)

### Requirement: Darwin machines are unaffected
The uutils replacement SHALL NOT apply to darwin machines. macOS machines SHALL continue using their native coreutils.

#### Scenario: britton-air unchanged
- **WHEN** the `nixos` tag config is evaluated for britton-air (darwin)
- **THEN** no uutils-coreutils package is added to the system

### Requirement: Nix build sandbox is unaffected
The replacement SHALL NOT use a nixpkgs overlay. stdenv and all derivation builds SHALL continue using GNU coreutils inside the sandbox.

#### Scenario: Package builds use GNU coreutils
- **WHEN** a Nix derivation builds inside the sandbox
- **THEN** the coreutils in `$PATH` inside the sandbox are GNU, not uutils
