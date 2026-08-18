## Why

The accepted RWKV diagnostics intentionally excluded tokenizer claims and used model-config BOS/EOS IDs `1` and `2`. The exact repository contains three conflicting contracts: `config.json` says BOS/EOS `1/2`; tokenizer metadata maps BOS special text to added-token ID `0`, maps EOS text `"\n\n"` to ordinary byte-vocabulary ID `261`, and the Hugging Face wrapper re-registers that EOS text as added-special ID `65,530`; `generation_config.json` overrides generation BOS/EOS to `0/0`. Vocabulary IDs `1` and `2` are bytes `0x00` and `0x01`. This conflict must be pinned and made explicit before a meaningful prompt-to-text claim.

## What Changes

- Pin the checkpoint's exact vocabulary, tokenizer configuration, added-token map, special-token map, tokenizer implementation, model configuration, and generation configuration at the already accepted revision with Nix SHA-256 and runtime BLAKE3 identities.
- Add a pure Rust tokenizer core that parses and validates all vocabulary rows, performs the reviewed longest-prefix byte encoding, decodes IDs to exact bytes, and rejects malformed, duplicate, missing, or out-of-contract data.
- Relabel the preserved `[1, 2]` and ID-`1` diagnostics as model-config ID tests, explicitly distinct from tokenizer and generation-configuration IDs.
- Add an argument-free fixed-chat-prompt harness that reproduces wrapper IDs `0` and `65,530`, uses generation-config BOS/EOS ID `0`, records ordinary byte EOS ID `261` separately, retains twelve-layer state, performs bounded greedy generation with normal generation-config EOS stopping, and emits exact token/byte/text receipts with full zero-state replay.
- Keep sampling, arbitrary prompts, framework numerical parity, hardware execution, ttWKV7 parity, P150 correctness, and performance explicitly excluded.

## Impact

- **Files**: `pkgs/rwkv-layer-harness`, `flake-outputs/ttwkv7.nix`, `README.md`, and the Tenstorrent native-runtime Cairn specification
- **Testing**: Baseline and final Rust tests, tokenizer positive/negative fixtures, upstream-reference tokenization comparison, deterministic real-checkpoint receipts, Nix install checks, formatting, Clippy, focused hooks, and Cairn gates
