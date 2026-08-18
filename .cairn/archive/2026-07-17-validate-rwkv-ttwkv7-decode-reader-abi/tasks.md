## Phase 1: Shared decode ABI and source model

- [x] [serial] Add a pure fixed-array decode ABI core and make production decode runtime-argument setup delegate to it without changing chunked behavior or production kernels. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_decode_reader_abi]
- [x] [serial] Add exact fixture validation, accepted host-buffer reconstruction, source-locked decode-reader emulation, and an independent complete logical payload oracle. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_decode_reader_abi]

## Phase 2: Cross-package evidence

- [x] [serial] Add deterministic runtime-vector, source-trace, state-payload, input-payload, and combined receipts with positive replay and adversarial ABI/gather/fixture controls. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_decode_reader_abi]
- [x] [serial] Run package, historical host-layout/data-movement, architecture, closure, formatting, and clean Cairn gates; record narrow evidence; sync, archive, and commit the accepted boundary. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_decode_reader_abi]
