## Phase 1: Service isolation

- [x] [serial] Isolate Metalium service processes by physical device visibility and remapped logical device selection. r[onix.tenstorrent.model_process_isolation.devices]
- [x] [serial] Give each Metalium process unique cache, logs, and inspector RPC state. r[onix.tenstorrent.model_process_isolation.state]

## Phase 2: Concurrent model deployment

- [x] [serial] Move Supra-Router-51M to physical P150 card 1 while preserving its API contract. r[onix.tenstorrent.concurrent_models.supra]
- [x] [serial] Keep VibeThinker on physical P150 card 0 and preserve the host-level P150x2 descriptor. r[onix.tenstorrent.concurrent_models.vibethinker]

## Phase 3: Verification

- [x] [serial] Run positive and negative evaluation, formatting, pre-commit, and the complete `britton-desktop` build. r[onix.tenstorrent.model_process_isolation.devices] r[onix.tenstorrent.model_process_isolation.state]
- [x] [serial] Switch the host and verify simultaneous health, physical card ownership, and valid concurrent model responses. r[onix.tenstorrent.concurrent_models.supra] r[onix.tenstorrent.concurrent_models.vibethinker]
