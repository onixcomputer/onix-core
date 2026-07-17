# Tasks: Repair ttWKV7 reader L1 scratch

- [x] [serial] Preserve the exhausted hardware result and prove the compiled scratch address is private stack/LDM rather than worker L1. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
- [x] [serial] Replace local reader arrays with Blackhole-only CB22-backed aligned worker-L1 scratch while preserving Wormhole behavior. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
- [x] [serial] Add positive and negative device-free validation for scratch ownership, host allocation, bounds, and architecture compilation. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
- [x] [serial] Pass the focused architecture/package checks, formatting, pre-commit, and Cairn gates without hardware access. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
- [ ] [serial] Sync the accepted requirement, archive the change with exact evidence, and make no physical-correctness claim. r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
