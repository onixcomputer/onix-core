## Phase 1: Bound the real repair

- [x] [serial] Capture current Trellis input identities, recorded runtime failure, direct consumer constraints and original Spark ownership. r[onix.nemotron-snapshot-repair.isolation]
- [x] [serial] Admit a pinned loopback-only Nemotron endpoint through an authenticated tunnel without changing persistent Spark configuration. r[onix.nemotron-snapshot-repair.runtime]

## Phase 2: Repair and independent acceptance

- [x] [serial] Run an actual bounded Nemotron repair on isolated source, retaining prompts, tools and verifier outputs. r[onix.nemotron-snapshot-repair.repair]
- [x] [serial] Integrate only a reviewed exact commitment with assumption-free proofs, migrate all active consumers and trust inventories, and prove runtime and full-corpus acceptance. r[onix.nemotron-snapshot-repair.acceptance]

## Phase 3: Restore ownership and record evidence

- [x] [serial] Stop owned model/tunnel resources, restore unchanged original DeepSeek containers, and prove an actual successful completion. r[onix.nemotron-snapshot-repair.restoration]
- [x] [serial] Record verified usage and source-bound evidence and validate native lifecycle artifacts. r[onix.nemotron-snapshot-repair.isolation]
