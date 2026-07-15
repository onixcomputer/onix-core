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
| Worker budgets | Reduce each service from the automatic 16 generation/batch threads while preserving graph/model settings | Fewer runnable CPU workers preserve both cards' dispatch cadence | active | Compare an explicit eight-thread candidate with the automatic baseline |
| CCD placement | Put each service on a disjoint physical-core/L3 domain | Cache and scheduler isolation remove cross-service host jitter | active | Apply disjoint `CPUAffinity` sets with unchanged model arguments |
| PCIe/power | Simultaneous cards contend for link, fabric, or board power | CPU changes cannot recover the loss if device telemetry/link pressure dominates | active | Capture non-mutating topology and telemetry around a synchronized run |
| Runtime serialization | Metalium or UMD serializes host work across otherwise isolated processes | Throughput loss persists with disjoint CPU resources and low CPU utilization | active | Correlate service CPU time, Inspector timing, and the affinity trial |
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
