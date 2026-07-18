# Change: Define the RWKV ttWKV7 dispatch ABI

## Why

The accepted physical ttWKV7 boundary now composes through a complete twelve-layer CPU model, but a future persistent Metalium owner has no small, deterministic request/response contract to implement. Calling device code directly from model recurrence would mix hardware ownership with numerical logic and make ordering, state retention, and BF16 transport difficult to audit.

## What Changes

- Define a versioned, canonical little-endian BF16 request/response frame for one RWKV WKV recurrence call.
- Split dispatch into pure request preparation, CPU response emulation, response validation, and transcript reduction cores.
- Exercise two retained-state tokens across all twelve logical layers with exact token/layer/call ordinals.
- Reject stale, reordered, duplicated, malformed, non-finite, shape-drifted, and trailing-byte frames.
- Emit a deterministic device-free receipt and package it as a Nix check without process, Metalium, device, or owner-service access.

## Impact

This adds a software-only ABI boundary that a later persistent Metalium shell can implement. It does not execute ttWKV7 on hardware, authorize a hardware process, establish model-generated dispatch vectors, or alter the terminal `unsafe` physical-session classification.
