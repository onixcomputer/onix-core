# Proposal: Carry RWKV through one persistent dispatch session

## Why

The accepted real-model dispatch rung proves that every third-token WKV call can traverse the canonical request/response ABI from the accepted physical-seeded token-two model state. It does not yet prove that one transport session can preserve strict authority across more than one model token, carry each layer's returned matrix into that layer's next request, or fail closed when a pending call times out or the session is interrupted.

## What changes

- Add a pure in-memory dispatch-session state machine with one pending request, exact sequence/call/token/layer progression, per-layer response-state continuity, terminal fault handling, and exact close requirements.
- Route all twelve WKV calls for the third token and the greedily selected fourth token through one logical session while retaining the accepted physical-seeded token-two model state.
- Compare both dispatched tokens against an independently ordered BF16 recurrence oracle and retain reset-all-matrices and per-head-transpose controls.
- Add negative tests for reordered requests, changed same-layer pre-state, stale/duplicate/reordered/truncated responses, timeout, interruption, premature close, calls after close/fault, and automatic retry/reconnect attempts.
- Add a fixed `--evidence-root PATH` replay, deterministic complete-vector/session receipt, Nix check, closure/source checks, and historical-receipt preservation.

## Scope

This change is entirely device-free. The word persistent describes continuity of one pure logical session across two model tokens. No operating-system child process, socket, Metalium runtime, device, owner-service action, retry, reconnect, or new hardware authorization is introduced. A separately authorized later change is required before persistent Metalium transport or physical third/fourth-token WKV execution.
