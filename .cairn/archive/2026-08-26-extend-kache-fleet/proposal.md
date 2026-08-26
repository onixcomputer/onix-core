## Why

Aspen1 and Aspen3 use the shared niks3 binary cache but do not use Kache for interactive Cargo builds. This leaves reusable Rust compiler output local to the desktop.

## What Changes

- Run one credentialed Kache daemon on each RustFS node.
- Give each daemon its node-local RustFS endpoint and a bounded local cache.
- Put Aspen3 cache data on its USB4 volume.
- Apply the managed Kache Cargo wrapper to `brittonr` on all three nodes.
- Keep Nix sandbox Kache local-only and without RustFS credentials.

## Impact

- **Files**: Kache Clan module, inventory, Home Manager profile, generated checks, accepted specification, and operator documentation
- **Testing**: typed fixtures, pure settings tests, generated fleet checks, all three NixOS builds, Clan vars checks, and runtime push/pull evidence
