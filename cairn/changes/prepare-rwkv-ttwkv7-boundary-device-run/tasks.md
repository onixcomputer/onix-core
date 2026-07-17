## Phase 1: Exact fixture and comparison core

- [x] [serial] Add the pure exact-fixture, complete-result comparison, artifact-manifest, and deterministic receipt core with positive and negative self-tests. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness]

## Phase 2: Shared production one-shot path

- [x] [serial] Parameterize the existing production execution shell for reviewed inputs and one-shot policy, then add strict DecodeL fixture mode without modifying production kernels. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness]
- [x] [serial] Preserve complete raw writer/output/post-state BF16 artifacts and apply only the predeclared finite `6e-2` output/state NMSE decision. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness]

## Phase 3: Isolated package and plan

- [x] [serial] Add the fixture-only package, exact wrapper, typed single-process `rwkv-lab` plan, no-device preflight, closure isolation, deterministic replay, and adversarial command/fixture controls. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness]

## Phase 4: Regression and lifecycle

- [x] [serial] Run package, historical host-layout/decode-reader/shape/data-movement/architecture, closure, formatting, and clean Cairn gates; record narrow no-device evidence, sync, archive, and commit. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness]
