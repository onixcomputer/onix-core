# Tasks: Fix ttWKV7 Blackhole reader gather alignment

- [x] [serial] Preserve terminal evidence, define the exact architecture contract and non-claims, and evaluate distinct gather mechanisms. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
- [x] [serial] Add a pure architecture alignment plan and one bounded aligned-scratch face-row helper with positive and negative compile-time assertions. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
- [x] [serial] Route chunked input/state gathers through the helper without changing ABI, CB order, chunk tail fill, or Wormhole direct reads. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
- [x] [serial] Route decode input/state gathers through the same helper without changing ABI, state/input order, or Wormhole direct reads. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
- [x] [serial] Add static negative checks that reject direct 32-byte Blackhole reader gathers and helper/cadence drift. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
- [x] [serial] Compile both readers and diagnostic peers for pinned Blackhole and Wormhole, then pass package and host checks. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
- [x] [serial] Adversarially audit alignment, scratch lifetime, CB cadence, Wormhole preservation, and claim boundaries. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
- [x] [serial] Pass formatting, pre-commit, and Cairn gates, sync the accepted requirement, and archive the device-free result without preparing a physical runbook. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
