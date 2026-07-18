## Why

The accepted physical ttWKV7 evidence now composes through layer zero and its matrix post-state survives one CPU recurrent continuation, but the resulting state has not yet been propagated through all twelve model layers to logits. A device-free all-layer composition is the smallest remaining structural boundary before any new hardware request.

## What changes

- Add a pure full-model replay that injects the exact physical layer-zero second-token WKV output and post-state, executes layers 1–11 on CPU, then carries the resulting all-layer state through one additional token.
- Compare source-FP32, expected-BF16, observed-physical-seed, reset-state, and transposed-state paths through final normalization and the untied language-model head.
- Lock per-layer outputs, complete recurrent state, logits, top-two tokens, divergence controls, prior receipt identities, and narrow non-claims in a deterministic receipt.
- Package a fixed evidence-root shell and adversarial Nix check without adding device or process surfaces.

## Impact

This establishes software composition from one accepted physical WKV boundary through all twelve recurrent layers and the language-model head. It does not establish a physical third-token WKV step, a wholly device-executed layer/model, hardware-backed generation, serving, throughput, or latency.
