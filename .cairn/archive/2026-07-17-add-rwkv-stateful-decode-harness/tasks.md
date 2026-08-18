# Tasks

- [x] [serial] Add the bounded stateful token-ID decode and incremental-versus-replay contract with explicit EOS and hardware non-claims. r[onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode]
- [x] [serial] Refactor the pure full-model core into explicit zero-state, one-token transition, sequence fold, and finalization while preserving accepted receipts. r[onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode]
- [x] [serial] Add the fixed three-step BOS-seeded decoder, replay audit, per-step fingerprints, and argument-free `rwkv-decode-harness` shell. r[onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode]
- [x] [serial] Add positive and negative Rust/Nix checks for state carry, input chaining, replay parity, EOS policy, determinism, schema, finiteness, and non-execution. r[onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode]
- [x] [serial] Run focused validation, lock the real-checkpoint decode receipt, sync the requirement, archive the change, and retain tokenizer, hardware, and text claims as excluded. r[onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode]
