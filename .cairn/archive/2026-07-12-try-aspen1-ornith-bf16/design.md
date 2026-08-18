## Context

`aspen1` currently serves `user.Ornith-1.0-35B-Q4_K_M` through Lemonade and llama.cpp with a 131,072-token context and Q8 KV caches. A live non-thinking probe returns `4` for `2+2`. The host reports 125 GiB total memory, 92 GiB available while Q4 is loaded, and 1.7 TiB free disk. Hugging Face publishes the official BF16 GGUF at 69,376,636,800 bytes.

The official 35B Q8 GGUF is not a valid substitute: prior CPU and ROCm probes produced repeated slash tokens. BF16 therefore needs behavioral validation rather than acceptance based only on successful download or load.

## Decisions

### 1. Add BF16 without replacing Q4

**Choice:** Register BF16 only on `aspen1` and retain Q4_K_M in the same Lemonade pull list.

**Rationale:** The additive registry change keeps a known-good rollback endpoint available throughout download, model load, and inference validation.

### 2. Preserve the deployed runtime settings for the first trial

**Choice:** Use the existing ROCm backend, 131,072-token context, Q8 KV caches, and cluster RPC policy for the initial BF16 probe.

**Rationale:** Holding runtime policy constant isolates model precision as the primary changed variable. If RPC availability blocks a load that otherwise fits locally, the failure will be diagnosed before changing cluster policy.

### 3. Require content and resource evidence

**Choice:** Accept the trial only when BF16 returns `4` for a non-thinking `2+2` probe, Lemonade remains active, and the host avoids OOM or swap distress. Re-probe Q4 after any BF16 failure.

**Rationale:** HTTP success or process startup alone previously produced false confidence for Q8. The trial needs a semantic oracle plus host-health evidence.

## Risks / Trade-offs

- BF16 adds about 48.2 GB over Q4 weights and may leave less headroom for long-context KV state and concurrent host services.
- Loading BF16 can temporarily interrupt requests because Lemonade permits one loaded model.
- Aspen2's RPC route was unavailable during preflight; a fresh distributed load may fall back locally or fail and require separate network diagnosis.

## Validation Evidence

- The Nickel service export and Cairn validation/gates passed before deployment.
- A clean detached worktree at `b310ac34` evaluated and built the Aspen1 system closure, excluding unrelated dirty-worktree changes.
- Aspen1 activated `/nix/store/j79rdbj7jq0yf2mgh20cd48chwix42ja-nixos-system-aspen1-26.11.20260629.7a1a647`.
- Lemonade downloaded and validated the 64.6 GiB `ornith-1.0-35b-bf16.gguf` artifact.
- BF16 returned content `4` with HTTP 200 for the non-thinking `2+2` probe on llama.cpp `b9859`; a second probe succeeded after exercising the fallback.
- Q4_K_M independently returned content `4` with HTTP 200 after BF16 had loaded.
- With BF16 loaded, Aspen1 reported 76 GiB used and 48 GiB available memory, 2.6 GiB swap used, an active Lemonade service, and no kernel OOM or Lemonade fatal/error records during the trial window.
- Final Nickel export and Cairn repository validation passed. The repository-wide traceability coverage rail remains globally failing because its current profile discovers zero evidence files for 173 accepted requirements; that pre-existing repository coverage gap is not treated as BF16 runtime evidence.
