## Phase 1: Add the dependency and service wiring

- [x] [serial] Add `github:Mic92/fast-nix-gc` as a flake input with shared nixpkgs/treefmt inputs. r[onix.store.fast_gc.dependency]
- [x] [serial] Import the upstream NixOS module from the existing `nix-gc` clan service wrapper. r[onix.store.fast_gc.module]
- [x] [serial] Render `services.fast-nix-gc` from existing store-maintenance retention and schedule settings. r[onix.store.fast_gc.gc]
- [x] [serial] Render `services.fast-nix-optimise` from existing store-maintenance optimization settings. r[onix.store.fast_gc.optimise]
- [x] [serial] Force stock scheduled GC and optimize timers off when the fast path is enabled. r[onix.store.fast_gc.no_duplicates]

## Phase 2: Preserve configuration intent

- [x] [serial] Add a schema toggle that falls back to stock Nix GC when fast-nix-gc is disabled. r[onix.store.fast_gc.fallback]
- [x] [serial] Expose fast GC tuning fields for free-space, recent-path, vacuum, extra-root, and extra-argument behavior. r[onix.store.fast_gc.tuning]
- [x] [serial] Port known tag-specific retention and schedule overrides to equivalent fast-nix-gc settings. r[onix.store.fast_gc.tag_overrides]
- [x] [serial] Keep `nix.settings.auto-optimise-store` controlled by the existing `autoOptimise` setting. r[onix.store.fast_gc.auto_optimise]

## Phase 3: Validate

- [x] [serial] Add README reference evidence for the upstream codebase. r[onix.store.fast_gc.dependency]
- [x] [serial] Run Cairn validation and focused Nix/Nickel checks for the changed service wrapper. r[onix.store.fast_gc.verification]
