## Phase 1: Implementation

- [x] [serial] Measure repeated Nickel machine parsing and map direct Nix consumers. r[onix.inventory.machine_evaluation.shared]
- [x] [serial] Share one raw inventory value through Clan, the machine library, NixOS tags, and all affected checks. r[onix.inventory.machine_evaluation.shared]
- [x] [serial] Verify raw data, names, tags, projections, check membership, and generated configuration remain unchanged. r[onix.inventory.machine_evaluation.preserved]
- [x] [serial] Record repeated before/after timings and scoped validation evidence. r[onix.inventory.machine_evaluation.measured]

## Evidence

- `benchmark.json`: immutable-source, alternating-order measurements with one warm-up per version and five measured pairs; all twelve outputs byte-identical.
- `verification.json`: raw inventory, projection, tag/laziness smoke results, focused Nix check builds, desktop derivation comparison, and source hashes.
- Desktop derivation addresses change because the canary workflow import embeds the repository source path. All six differing derivations normalize exactly after substituting that source identity and consequent derivation/output addresses; the workflow file matches the retained baseline.
