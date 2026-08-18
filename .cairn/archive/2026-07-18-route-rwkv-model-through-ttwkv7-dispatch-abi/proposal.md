# Change: Route real RWKV model state through the ttWKV7 dispatch ABI

## Why

The repository now has both a complete twelve-layer device-free continuation from the accepted physical layer-zero state and a canonical framed WKV dispatch ABI, but the two boundaries remain separate. Before any persistent Metalium process can be considered, real model-derived third-token WKV inputs and all twelve retained layer states must traverse the exact ABI without changing model semantics or historical receipts.

## What Changes

- Reconstruct the accepted physical-seeded second-token model state from immutable evidence.
- Route all twelve third-token WKV calls through canonical BF16 request/response frames and the device-free CPU dispatcher.
- Compare framed execution against an independently ordered BF16 CPU oracle while preserving FP32 host projections, residuals, normalization, channel mix, and untied head.
- Bind every real model request and response, layer output, complete state, logits, and top-two ranking into a deterministic receipt.
- Require retained, reset, and per-head-transposed all-layer controls and reject evidence, invocation, ordering, response-authority, and source-surface drift.

## Impact

This closes the software boundary between physical-seeded model state and a future persistent ttWKV7 dispatcher. It does not open a device, run a process transport, execute the third token physically, authorize hardware, or change the terminal `unsafe` session outcome.
