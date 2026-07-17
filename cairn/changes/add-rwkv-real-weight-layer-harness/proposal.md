# Proposal: Add a real-weight RWKV-7 layer harness

## Why

The device-free `rwkv-lab` boundary can now bind and classify a future session, while ttWKV7 remains only a standalone recurrence operator. The next integration rung is to prove that a pinned real RWKV-7 checkpoint can be decoded into the exact layer-zero inputs and state shape expected by that recurrence. Synthetic operator tests do not validate checkpoint tensor names, orientations, BF16 decoding, time-mix projections, recurrent state carry, group normalization, channel mix, or residual composition.

A CPU-only two-token, one-layer harness provides that discriminator without opening Metalium. It should produce stable fingerprints for the real recurrence inputs, state, and layer output while retaining full-model logits and token generation as explicit non-claims.

## What Changes

- Pin the Apache-2.0 `RWKV/RWKV7-Goose-World2.8-0.1B-HF` safetensors checkpoint at exact revision `d81965cb4e1a9f96696b4f70b84212b8f2e43216`.
- Add a Rust `rwkv-layer-harness` package that decodes the checkpoint's BF16 layer-zero tensors and runs BOS/EOS through one RWKV-7 block in CPU FP32.
- Emit deterministic BLAKE3 fingerprints and finite-value statistics for the recurrence vectors, carried state, and layer output.
- Cross-check the recurrence against an independently structured host-oracle implementation and reject shape, dtype, digest, non-finite, and state-layout regressions.
- Add positive and negative pure-core tests plus a Nix real-weight integration check.
- Record BlinkDL RWKV-LM, FLA v0.3.0, and the pinned Hugging Face checkpoint as references.

## Non-Goals

- No Tenstorrent device access, owner isolation, Metalium initialization, or ttWKV7 process.
- No claim of P150 numerical parity or repaired-reader completion.
- No full twelve-layer model, tokenizer, logits, greedy token, or text generation.
- No use of the FLA warning-prone implementation as proof of general RWKV correctness.
