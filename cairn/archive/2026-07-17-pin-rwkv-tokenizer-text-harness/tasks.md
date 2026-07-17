## Phase 1: Authority and semantic correction

- [x] [serial] Pin and validate the seven exact tokenizer/model/generation artifacts and add the pure exhaustive vocabulary/config parser. r[onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text]
- [x] [serial] Relabel preserved fixed-ID layer, token, and stateful receipts without changing their accepted numerical evidence. r[onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text]

## Phase 2: Tokenizer and model integration

- [x] [serial] Add longest-prefix encoding, exact byte decoding, special-token handling, and upstream-reference positive and negative fixtures. r[onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text]
- [x] [serial] Add the argument-free fixed-chat-prompt harness with exact wrapper specials, retained state, bounded greedy generation, generation-config EOS stopping, replay, and deterministic text receipts. r[onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text]

## Phase 3: Acceptance

- [x] [serial] Run focused Rust/Nix and Cairn validation, lock exact tokenizer/text evidence, sync the requirement, archive the change, and preserve hardware/framework/performance exclusions. r[onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text]
