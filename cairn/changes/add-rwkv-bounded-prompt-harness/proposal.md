## Why

The accepted fixed-text receipt proves one pinned prompt, but it deliberately excludes a caller-supplied prompt interface. The existing Rust recurrence and replay oracles are also structurally related implementations inside one codebase; they do not provide a framework-level numerical comparison. The next device-free rung should accept bounded user text without opening model, file, network, subprocess, or hardware authority, and should compare the complete model output against a separately structured pinned PyTorch equation reference.

## What Changes

- Add a `rwkv-prompt-harness` CLI that accepts one UTF-8 user message plus explicit prompt-token and generated-token limits, applies named package hard caps, uses only the embedded Nix-store checkpoint and tokenizer authorities, and emits deterministic exact-byte receipts.
- Extract pure request parsing, validation, chat rendering, and bounded execution cores while keeping argument, Nix-store file, stdout, and error handling in a thin binary shell.
- Preserve the argument-free fixed-text receipt and all previously accepted layer, greedy-token, and stateful-decode evidence unchanged.
- Add pinned Hugging Face, FLA v0.3.0, and official RWKV source authorities plus a separately structured CPU PyTorch FP32-from-BF16 equation reference.
- Compare complete final hidden, logits, and recurrent matrices for the accepted model-config prefix `[1, 2]`, require exact top-two ranking, and report maximum absolute deviations under named tolerances.
- Keep FLA runtime parity, Transformers generation parity, hardware execution, P150 correctness, ttWKV7 parity, linguistic quality, long-context stability, and performance explicitly excluded.

## Impact

- **Files**: `pkgs/rwkv-layer-harness`, `flake-outputs/ttwkv7.nix`, `README.md`, and the Tenstorrent native-runtime Cairn specification
- **Testing**: baseline and final Rust tests, positive and negative CLI/request fixtures, deterministic bounded custom-prompt receipts, pinned-source identity checks, a CPU PyTorch comparison, Nix install/check derivations, formatting, Clippy, focused hooks, and Cairn gates
