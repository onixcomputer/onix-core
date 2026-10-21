## Context

The machine library, Clan inventory, four check modules, and NixOS tag argument each evaluate the same Nickel file independently. The existing `nclMachines` argument shares values only among tags within one machine configuration.

## Decisions

### Decision: Share a flake-level lazy value

**Choice:** Bind `machineDefinitions` once in `flake-outputs/clan.nix`. Export the same value as `lib.machines.definitions`, retain the existing `names` and `hasTag` operations, and pass the value explicitly through the inventory import to its core projection. Existing tag consumers continue using `nclMachines`, now referencing the flake-level value.

**Rationale:** A Nix lazy value is shared within an evaluator process without persistent cache state, invalidation logic, or duplicated parsing. The raw value does not depend on Clan, so inventory evaluation cannot recurse through Clan configuration. Keep the existing x86_64-linux WASM plugin choice used by the raw inventory and checks.

## Risks / Trade-offs

- Keep `system` and `addresses` in raw definitions and strip them only at the existing Clan projection.
- Retain independent Nickel imports in user, service, and builder contracts: combining those interpreters would change validation strictness.
- Preserve the system-specific `wasm` module argument for other tag data; only `nclMachines` becomes globally shared.
- Compare supported-platform check names and real generated configuration, not merely evaluation success. The baseline already rejects x86_64-darwin because nixpkgs 26.11 dropped support.
- Timings on this shared host can be noisy. Record warm-up separately, repeated wall/CPU timings, output hashes, and Nix allocation statistics; do not generalize metadata timings to full builds.

## Verification

The retained interleaved benchmark reduced median metadata wall time from 8.354 to 6.675 seconds (20.1%) and evaluator CPU time from 7.619 to 6.281 seconds (17.6%). Machine inventory and all 459 check names across three supported platforms remained byte-identical. Nix allocation totals were essentially unchanged; this removes redundant WASM/Nickel execution rather than the broader Nix module graph.

Raw-data, Clan-projection, tag-membership, platform-selection, and laziness smoke assertions passed. The `builder-no-self` and `ssh-host-key-consistency` checks built successfully. Full desktop derivation evaluation passed; its only transitive content difference is the canary workflow's repository source address, with identical workflow content in the retained baseline and current checkout. See `benchmark.json` and `verification.json` for scope and evidence.
