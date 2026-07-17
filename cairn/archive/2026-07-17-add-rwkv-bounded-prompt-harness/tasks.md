## 1. Bounded prompt interface

- [x] [serial] Add pure caller-request parsing, named hard-cap validation, exact chat rendering, and positive/negative boundary tests. r[onix.tenstorrent.native_runtime.rwkv_lab.bounded_prompt]
- [x] [serial] Refactor fixed-text execution through a shared core without changing the accepted fixed receipt, then add the thin `rwkv-prompt-harness` shell and deterministic bounded prompt evidence. r[onix.tenstorrent.native_runtime.rwkv_lab.bounded_prompt]

## 2. Framework comparison

- [x] [serial] Pin the Hugging Face, FLA v0.3.0, and official RWKV equation authorities and add an argument-free complete-vector Rust fixture. r[onix.tenstorrent.native_runtime.rwkv_lab.torch_equation_parity]
- [x] [serial] Add the separate CPU PyTorch FP32-from-BF16 equation adapter with complete-vector positive comparison and malformed/changed negative fixtures. r[onix.tenstorrent.native_runtime.rwkv_lab.torch_equation_parity]

## 3. Validation and lifecycle

- [x] [serial] Run focused Rust/Nix and Cairn validation, lock bounded-prompt and PyTorch comparison evidence, preserve narrow non-claims, sync, archive, and commit the accepted boundary. r[onix.tenstorrent.native_runtime.rwkv_lab.bounded_prompt] r[onix.tenstorrent.native_runtime.rwkv_lab.torch_equation_parity]
