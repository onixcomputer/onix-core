## Phase 1: Metalium service support

- [x] [serial] Add the pinned Metalium backend and explicit device selection to `llamacpp-server`. r[onix.llamacpp_server.metalium_backend]
- [x] [serial] Enforce positive and negative runtime configuration boundaries for CPU KV cache, flash attention, tracing, and mesh exclusion. r[onix.llamacpp_server.metalium_safety]

## Phase 2: VibeThinker deployment

- [x] [serial] Configure `britton-desktop` VibeThinker Q8_0 serving on Blackhole device 0 with the measured batch settings. r[onix.vibethinker.metalium_serving]
- [x] [serial] Evaluate the generated systemd service and preserve the native P150x2 descriptor for non-llama.cpp workloads. r[onix.vibethinker.metalium_serving]

## Phase 3: Verification

- [x] [serial] Run formatting, pre-commit, focused positive/negative evaluation, and `britton-desktop` Nix evaluation. r[onix.llamacpp_server.metalium_backend] r[onix.llamacpp_server.metalium_safety]
- [x] [serial] Validate Cairn proposal/design/tasks gates and record the measured OpenAI-compatible generation evidence. r[onix.vibethinker.metalium_serving]
