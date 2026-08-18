## Why

The shared `store-maintenance` service currently enables stock `nix-collect-garbage` and `nix-store --optimise` timers. On larger Onix stores those stock commands spend substantial time traversing the Nix SQLite reference graph and deduplicating serially, which makes scheduled maintenance slow and more disruptive than necessary.

Mic92's `fast-nix-gc` provides compatible Nix store garbage collection and optimization binaries plus NixOS modules. Integrating it through the existing clan service keeps the inventory surface stable while replacing the expensive scheduled maintenance path.

## What Changes

- Add `github:Mic92/fast-nix-gc` as a flake input.
- Import the upstream NixOS module from the existing `nix-gc` clan service wrapper.
- Configure `services.fast-nix-gc` and `services.fast-nix-optimise` from the current store-maintenance settings.
- Disable stock scheduled `nix.gc` and `nix.optimise` when the fast path is enabled to avoid duplicate collectors.
- Preserve a settings escape hatch that can fall back to stock Nix GC.
- Update aggressive GC tags to set equivalent fast-nix-gc options.

## Impact

- **Scope**: NixOS machines with the existing `store-maintenance` service role.
- **Risk**: Upstream tool behavior must stay compatible with Onix's pinned Nix and store settings; duplicate timers must not run.
- **Non-goals**: Do not change Darwin GC behavior in this change. Do not remove existing Nix daemon `auto-optimise-store` support.
- **Testing**: Validate Cairn artifacts, evaluate the changed Nix modules, and check positive/negative inventory validation for the new settings fields.
