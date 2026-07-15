## Context

`britton-desktop` runs VibeThinker-3B Q8_0 on physical P150 card 0 (PCIe Gen5 x8) and Supra-Router-51M on card 1 (PCIe Gen5 x4). Each process sees one physical card through `TT_VISIBLE_DEVICES`, uses logical Metalium device 0, and owns private compilation/log state. Both services keep F16 KV cache on the CPU and use the Metalium program cache.

A fixed-input baseline on 2026-07-15 established these warm results:

- VibeThinker chat completion: 64 generated tokens, about 22 decode tokens/s and 2.95 seconds end to end.
- Supra direct completion: 55 generated tokens, about 89 decode tokens/s and 0.64 seconds end to end after compilation.
- Cold prompt shapes are materially slower before JIT/program reuse.

The controlled rollout produced model-specific results:

- Supra retained byte-identical routing output while median warm decode increased from 88.32 to 136.15 tokens/s, a 54.15% gain. Alternating code and poetry prompts produced stable prompt-specific outputs, falsifying the stale-input replay concern for the tested shapes.
- VibeThinker retained byte-identical output but median warm decode fell from 22.06 to 18.13 tokens/s, a 17.81% regression. Its trace opt-in was rolled back declaratively.
- Both services remained isolated and reported zero restarts or new warning-level journal entries during the trials.

The pinned fork contains `GGML_METALIUM_TRACE`: pass 1 executes eagerly, pass 2 captures, and pass 3 onward replays the device command trace. The source labels this path unstable and has no focused trace test in the pinned checkout, so configuration plausibility is not acceptance evidence.

Alternative mechanisms remain bounded:

- The prior 1x2 llama.cpp mesh experiment replicated work and was slower; it is falsified for these services.
- TT-Inference-Server does not list VibeThinker or Supra for p150/P150x2; migration is blocked on model support.
- Firmware 18.8.0 triggers a multi-ERISC compatibility warning, but these services use single-card WORKER dispatch. Firmware 19.11.0 remains a manual operator action and is not part of this experiment.
- Lower quantization can change output quality and is excluded until same-precision runtime tuning is exhausted.

## Decisions

### Decision: Roll out trace replay one service at a time

**Choice:** Enable trace replay first for Supra-Router-51M, benchmark it against the fixed baseline, and enable it for VibeThinker only if Supra remains correct and materially faster.

**Rationale:** Supra has the smallest state and shortest recovery time. Sequential rollout preserves one known-good model service while the experimental path is tested.

### Decision: Require deterministic performance and correctness evidence

**Choice:** Use identical prompts, sampling, token limits, warmup count, repetition count, and output checks before and after each candidate. Define `minimumMaterialThroughputGainPercent` as 5; gains below that threshold are treated as noise and rolled back.

**Rationale:** First-run compilation, prompt caching, and graph reuse can create false wins. Median warm decode throughput and end-to-end latency must improve without token-count or output-schema drift.

### Decision: Prewarm only validated graph shapes

**Choice:** After trace replay passes the bounded benchmark, use a bounded service `postStart` warmup that waits for readiness and exercises enough identical requests to complete eager execution and capture before systemd treats the service start as complete.

**Rationale:** Trace replay does not accelerate the first two matching graph passes. Controlled prewarming moves compilation/capture cost out of user-visible requests while keeping the server process as the owner of device state.

### Decision: Keep rollback declarative

**Choice:** A trace candidate that crashes, restarts, produces invalid output, contends for the other card, or misses the material-gain threshold MUST return to `GGML_METALIUM_TRACE=0`; firmware is never flashed as rollback or tuning automation.

**Rationale:** A checked-in known-good configuration is safer than runtime mutation, and it preserves the existing manual firmware boundary.

## Risks / Trade-offs

- Trace replay pins graph buffers and can increase device memory use or expose stale-input bugs.
- A warmup shape only prepares matching graph signatures; varied prompt lengths can still pay capture cost later.
- Prompt-cache hits and graph reuse can mask prompt-evaluation costs, so decode and end-to-end metrics must both be reported.
- The fixed minimum material gain rejects small real improvements in exchange for a lower false-positive rate.
