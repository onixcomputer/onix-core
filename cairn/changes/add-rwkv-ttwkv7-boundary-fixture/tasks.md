## 1. Boundary capture core

- [x] [serial] Capture the retained layer-zero second-token pre-state, six WKV vectors, raw output, and post-state without changing historical receipts. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_fixture]
- [x] [serial] Add explicit little-endian BF16 artifacts, ordered combined BLAKE3 identity, BF16-decoded matrix/scalar recurrence comparison, and positive/negative core tests. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_fixture]

## 2. Reproducible fixture shell

- [x] [serial] Add the argument-free fixture binary, install its canonical JSON, and validate complete lengths, fixed ABI order, deterministic bytes, exact identities, and argument rejection. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_fixture]
- [ ] [serial] Run focused Rust/Nix and clean Cairn validation, record narrow evidence, sync, archive, and commit the accepted boundary. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_fixture]
