## Phase 1: Establish the standalone package authority

- [x] [serial] Preserve the exact pinned upstream lineage, configure the OnixResearch destination, and record the migration boundary and source revision. r[onix.tenstorrent.native_runtime.dedicated_repository]
- [x] [serial] Port reusable package, harness, bounded wrapper, benchmark, simulator, and retained-evidence sources while excluding fleet configuration and unrelated work. r[onix.tenstorrent.native_runtime.dedicated_repository]
- [x] [serial] Expose standalone packages and positive/negative checks from the dedicated flake and validate them without accelerator access. r[onix.tenstorrent.native_runtime.dedicated_repository]

## Phase 2: Switch the consumer and close out

- [x] [serial] Push validated destination `main`, update the `onix-core` input through Nix, and consume dedicated outputs instead of duplicate source trees. r[onix.tenstorrent.native_runtime.dedicated_repository]
- [x] [serial] Run focused consumer checks, formatting, Cairn gates/validation, sync the accepted requirement, archive the change, and preserve hardware execution as a non-claim. r[onix.tenstorrent.native_runtime.dedicated_repository]
