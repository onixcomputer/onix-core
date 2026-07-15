## Context

`britton-desktop` runs VibeThinker-3B on physical P150 card 0 and Supra-Router-51M on physical P150 card 1. Device visibility, cache, logs, and Inspector state are already isolated. Supra trace replay is prewarmed and produces 156.44 median isolated decode tokens/s; VibeThinker remains on its faster non-trace path. A simultaneous probe completed correctly but reduced Supra to 59.95 tokens/s and VibeThinker to 19.30 tokens/s.

The host is a single-socket Ryzen 9 9950X3D with 16 physical cores, SMT, and two eight-core L3/CCD domains: logical CPUs 0-7 and 16-23 share L3 domain 0; CPUs 8-15 and 24-31 share L3 domain 1. Both P150s report node-local CPUs 0-31. Card 0 negotiates PCIe Gen5 x8 and card 1 Gen5 x4. Both deployed llama-server processes currently span CPUs 0-31, use 16 generation/batch threads plus 31 HTTP threads, and own 89 runtime threads. The pinned llama.cpp guidance in `docs/development/token_generation_performance_tips.md` warns that excess generation threads can severely oversaturate a CPU even with accelerator offload, so explicit worker budgets are the first discriminating trial.

## Baseline Evidence

The checked Rust harness rejected pre-existing traffic, synchronized each concurrent pair with a barrier, validated response token counts/schema, and reconciled service token counters. Five rounds produced:

- VibeThinker: 19.235 isolated versus 11.856 concurrent decode tokens/s, retaining 61.64% and losing 38.36%.
- Supra: 128.815 isolated versus 17.908 concurrent decode tokens/s, retaining 13.90% and losing 86.10%.
- Geometric mean concurrent retention: 29.27%.
- All VibeThinker responses shared BLAKE3 `47467d125fd1ce97124465e883a4f11c617a1d4bbc27c7efa5273957787e9d45`; all Supra responses shared BLAKE3 `c2473faeda8e011b1eec2797d5bf2e047b4e9cf19ec4171709bf824ae2f84014`.
- Traffic accounting observed exactly 640 VibeThinker and 550 Supra predicted tokens, with no pre-existing or residual request.

## Candidate Results

### Eight generation and batch workers per service: validated

The first candidate changed only each server's generation and batch worker count from 16 to 8. The first five-round trial measured 22.755 isolated and 21.222 concurrent tokens/s for VibeThinker plus 168.631 isolated and 119.784 concurrent tokens/s for Supra. Relative to baseline, concurrent rates improved 79.00% and 568.90%, while normalized retention improved 178.06%.

A second five-round trial provided the conservative result: VibeThinker measured 18.673 isolated and 18.508 concurrent tokens/s; Supra measured 129.653 isolated and 97.182 concurrent tokens/s. Isolated VibeThinker remained within tolerance at -2.92%, isolated Supra improved 0.65%, concurrent VibeThinker improved 56.10%, concurrent Supra improved 442.68%, and normalized retention improved 194.45%. Every response retained its baseline BLAKE3 and traffic accounting was exact in both trials.

### Disjoint CCD placement: rejected

With the eight-worker candidate retained, a runtime-only trial constrained VibeThinker to the 96 MiB L3 CCD and Supra to the 32 MiB L3 CCD. Compared with the immediately preceding thread-only trial, concurrent rates improved 8.89% and 9.34%, but isolated rates improved more (10.39% and 16.26%), so normalized concurrent retention regressed 3.69%. The candidate failed the declared objective and all runtime `AllowedCPUs` overrides were removed; both units again inherit CPUs 0-31.

Board telemetry continued to report PCIe Gen5 x8/x4, 1350 MHz AI clocks, 63-64°C ASIC temperatures, and no corrected or uncorrected GDDR errors. This does not prove PCIe/power independence, but the worker-count recovery falsifies PCIe, power, or cross-process runtime serialization as the primary cause of the measured collapse.

## Success Contract

The exact goal is to improve simultaneous model serving while preserving isolated throughput, deterministic output, device/state isolation, and service availability.

Completion evidence requires five isolated requests per service and five synchronized concurrent rounds on identical fixed inputs. A candidate is accepted only when:

- every request succeeds with the expected token count and output structure;
- neither service's isolated median decode throughput regresses by more than the 5% noise tolerance;
- neither service's concurrent median decode throughput regresses by more than 5%;
- at least one concurrent median improves by more than 5%, and the geometric mean of each service's concurrent-to-isolated retention improves by more than 5%; and
- both units remain active with zero new restarts, device-contention failures, or fatal runtime errors.

HTTP success alone, a single fast sample, isolated-only improvement, an improvement caused by fewer output tokens, a quality/quantization change, or transferring latency from one service to the other is false completion. Firmware flashing and physical PCIe rewiring are excluded from automated trials.

## Portfolio Budget

Use at most two evidence rounds and three deployed candidate configurations. Each configuration receives five isolated requests per service and five synchronized concurrent rounds. Retrieval is bounded to the pinned llama.cpp/Metalium source, local topology/runtime telemetry, and the official TT-Metal tools guidance. Stop with a validated candidate, an exact environmental blocker, or all three candidates falsified.

## Approach Registry

| Family | Mechanism | Claim | State | Smallest discriminating check |
|---|---|---|---|---|
| Worker budgets | Reduce each service from the automatic 16 generation/batch threads while preserving graph/model settings | Fewer runnable CPU workers preserve both cards' dispatch cadence | validated | Two five-round trials satisfy the acceptance rule |
| CCD placement | Put each service on a disjoint physical-core/L3 domain | Cache and scheduler isolation remove cross-service host jitter | falsified | Normalized retention regressed 3.69%; runtime override removed |
| PCIe/power | Simultaneous cards contend for link, fabric, or board power | CPU changes cannot recover the loss if device telemetry/link pressure dominates | audit | Stable clocks/temperature and worker recovery reject it as the primary cause |
| Runtime serialization | Metalium or UMD serializes host work across otherwise isolated processes | Throughput loss persists after reducing runnable CPU workers | falsified | Concurrent rates recovered 56.10% and 442.68% in the conservative repeat |
| Backend/model migration | Replace llama.cpp or lower model quality | A different stack could avoid the bottleneck | blocked | Excluded unless pinned support and output parity exist |
| Firmware mutation | Upgrade board firmware to enable multi-ERISC | New firmware might change fabric behavior | blocked | Manual operator decision only; not an automated performance trial |

## Decisions

### Decision: Measure a Pareto-safe concurrent objective

**Choice:** Compare per-service medians and normalized concurrent retention rather than summing raw tokens/s across different models.

**Rationale:** Raw rates are not interchangeable across a 3B generator and a 51M router. The acceptance rule prevents a large Supra gain from hiding a VibeThinker regression and prevents isolated speed from masking concurrent collapse.

### Decision: Separate worker-count and CPU-placement trials

**Choice:** Test llama.cpp worker budgets independently before combining them with disjoint CCD affinity.

**Rationale:** Changing one mechanism at a time identifies whether the bottleneck is runnable-thread pressure or cache/scheduler placement. A combined candidate is reserved for the third and final trial only if both partial results justify it.

### Decision: Keep hardware and output semantics fixed

**Choice:** Preserve models, quantization, context, batch sizes, trace policy, physical-card assignment, ports, and deterministic request bodies throughout the search.

**Rationale:** This keeps throughput differences attributable to scheduling rather than model quality, graph shape, or device migration.

## Risks / Trade-offs

- The desktop is not a laboratory-isolated host; the five-run median and 5% tolerance bound ordinary jitter but do not prove all workload shapes.
- CCD affinity can hurt a service if Metalium host dispatch benefits from cross-CCD CPU capacity; every affinity trial therefore requires isolated rollback evidence.
- `tt-smi` sampling may perturb runtime timing, so telemetry is collected outside measured request windows unless a non-invasive sysfs source is available.
- A result can establish a safe deployment for these fixed workloads without proving the same thread budget for other models or prompt lengths.
