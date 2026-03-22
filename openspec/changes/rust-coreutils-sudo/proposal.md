## Why

Ubuntu 25.04 ships Rust coreutils (uutils) and sudo-rs by default, replacing GNU coreutils and the C sudo. Both projects are mature enough for production. uutils-coreutils 0.7.0 and sudo-rs 0.2.13 are in nixpkgs. Switching reduces exposure to C memory safety bugs in two of the most privileged components on the system — coreutils runs constantly, sudo runs as root.

## What Changes

- Replace GNU coreutils with `uutils-coreutils-noprefix` on all NixOS machines via the `nixos` tag
- Replace C sudo with `sudo-rs` on all NixOS machines via the `nixos` tag
- Keep GNU coreutils available as a fallback package for any scripts that hit uutils edge cases
- Preserve all existing sudo configuration: `extraRules` on britton-desktop, srvos `execWheelOnly`, PAM/fprintd settings
- Darwin machines are unaffected (macOS has its own coreutils and sudo)

## Capabilities

### New Capabilities
- `rust-coreutils`: Replace GNU coreutils with uutils-coreutils-noprefix across all NixOS machines
- `rust-sudo`: Replace C sudo with sudo-rs across all NixOS machines

### Modified Capabilities

(none — no existing specs are affected)

## Impact

- `inventory/tags/nixos.nix` or a new `inventory/tags/common/rust-replacements.nix` — primary config location
- `machines/britton-desktop/configuration.nix` — sudo extraRules must work with sudo-rs
- srvos `security.sudo.execWheelOnly` — must verify sudo-rs respects this option
- All NixOS machines (britton-fw, bonsai, aspen1, aspen2, britton-desktop, pine, utm-vm) are affected
- britton-air (darwin) is not affected
- GNU coreutils stays in the closure as a fallback; only the default PATH priority changes
