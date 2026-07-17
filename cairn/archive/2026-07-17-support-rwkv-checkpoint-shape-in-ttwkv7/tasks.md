## 1. Host shape core

- [x] [serial] Add checked shape derivation, exact positive-integer parsing, padded native-input construction, and focused positive/negative unit self-tests to the packaged ttWKV7 host. r[onix.tenstorrent.native_runtime.ttwkv7.checkpoint_shape]
- [x] [serial] Route test and benchmark preparation through ceiling head-tile and chunked-work counts while preserving default `S=64`, `H=32` behavior and all production kernels. r[onix.tenstorrent.native_runtime.ttwkv7.checkpoint_shape]

## 2. Device-free package evidence

- [x] [serial] Add the argument-free `shape-test` mode, install the patched host source, and add exact positive plus floor-division, missing-padding, malformed-argument, and suffix negative checks. r[onix.tenstorrent.native_runtime.ttwkv7.checkpoint_shape]
- [x] [serial] Run focused package, architecture, formatting, and clean Cairn gates; record narrow evidence; sync, archive, and commit the accepted boundary. r[onix.tenstorrent.native_runtime.ttwkv7.checkpoint_shape]
