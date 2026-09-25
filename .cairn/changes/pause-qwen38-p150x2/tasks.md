## Phase 1: Implementation

- [x] [serial] Mask `qwen38-p150x2.service` on `britton-desktop`, and document the pause in the host guide and `AGENTS.md`. r[onix.tenstorrent.p150x2_qwen.deployment]
- [x] [serial] Make the machine check require the mask while keeping the unit's contract assertions. r[onix.tenstorrent.p150x2_qwen.deployment]

## Phase 2: Verification and deployment

- [x] [serial] Run the machine check, deploy `britton-desktop` from its deployed lineage, and confirm on the target that the unit is masked, a start is refused, and no process holds either P150 device. r[onix.tenstorrent.p150x2_qwen.deployment]

Evidence: `evidence/qwen38-p150x2-pause-2026-09-25.md`.
