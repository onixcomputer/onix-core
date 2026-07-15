## Phase 1: Hardware truth

- [x] [serial] Remove the absent NVIDIA accelerator tag and regenerate live hardware facts while retaining Tenstorrent placement. r[onix.britton_desktop.accelerators.inventory]
- [x] [serial] Add positive and negative regression checks for the machine accelerator tags. r[onix.britton_desktop.accelerators.inventory]
- [x] [serial] Remove the NVIDIA-only Krea service assignment from this host. r[onix.britton_desktop.accelerators.services]

## Phase 2: Debugging guidance

- [x] [serial] Reference the official TT-Metalium tools index and document the production-to-source debugging escalation path. r[onix.tenstorrent.debugging.tooling_reference]
- [x] [serial] Correct stale agent and display guidance that assumes installed NVIDIA hardware. r[onix.britton_desktop.accelerators.inventory]

## Phase 3: Verification

- [x] [serial] Run formatting, positive/negative checks, pre-commit, and the complete `britton-desktop` build. r[onix.britton_desktop.accelerators.inventory] r[onix.britton_desktop.accelerators.services] r[onix.tenstorrent.debugging.tooling_reference]
- [x] [serial] Switch the host and verify PCI truth, removed NVIDIA/Krea units, and healthy concurrent Metalium models. r[onix.britton_desktop.accelerators.inventory] r[onix.britton_desktop.accelerators.services]
