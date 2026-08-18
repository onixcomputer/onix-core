# Design: Persistent Metalium partial-diagnostic evidence

## Result boundary

Pueue task `281` invoked the archived runbook exactly once. The process exited status `1`, timed out `false`, and the immutable `rwkv-lab` outcome is `partial_diagnostic`. Process, isolation, and restoration counts are each one; retry and reconnect counts are zero. The owner returned active/running with HTTP `200` and `NRestarts=0`; rollback was disarmed; both postflight board samples passed with `DDR_STATUS=0x5555`, zero GDDR errors, zero thermal trips, and advancing heartbeat.

The 207,544-byte transcript contains one 107,588-byte request and one nominal 99,940-byte response capture. The response capture begins with 3,793 UTF-8 Metalium logger bytes. Canonical `RKW7RSP1` appears exactly once at offset 3,793 within that capture, leaving a 96,147-byte canonical response prefix. Its authority identifies call `0`, token `2`, layer `0`, dimensions `H=12`, `S=64`, and `C=768`. The complete 768-value BF16 raw output and 47,255 complete BF16 post-state values are finite; 1,897 post-state values are missing.

Metalium Inspector independently records one initialized unit mesh, one mesh workload, one `InFlight` to `Committed` transition, one workload destruction, and the three production DecodeL kernels. Because the server constructs and writes the canonical response only after `run_wkv7` returns, this supports exactly one completed physical WKV call and one workload commit. The host accepted zero physical responses because logger bytes corrupted the stdout framing.

## Validation

The immutable 50-file raw evidence manifest is 4,627 bytes with BLAKE3 `f8b36780a6ab3800564ea14a46a39ef903291cafd62341402a2678b30db148e4`. The deterministic 707-byte diagnostic receipt has BLAKE3 `4259c6a2aa5706fab7e8c862d90111c5b425a1a4a0b917d872ed5cccb6f1f4e8`; its dedicated check output is `/nix/store/240w75857czhga65y4im7sxc04688h3h-rwkv-ttwkv7-persistent-partial-diagnostic`. The checker rejects response-magic mutation, transcript truncation, classification drift, workload-status drift, health drift, and missing or extra invocation arguments.

## Non-claims

This evidence does not establish an accepted canonical physical response, complete post-state, numerical agreement, physical same-layer continuity, physical third/fourth-token execution, 24 physical calls, a complete layer/model, generation, serving, throughput, latency, exact BF16 parity, or general P150 compatibility. No retry or substitute hardware command is permitted under task `281` or this evidence boundary.
