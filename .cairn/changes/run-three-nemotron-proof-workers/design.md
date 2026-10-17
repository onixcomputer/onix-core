## Context

The existing launcher pins the public Nemotron 3.5 Super VL 120B/A12B NVFP4 base, LiLiCorr draft, and ARM64 vLLM image. Each Spark has GB10 and approximately 121 GiB unified memory; the launcher admits at least 100 GiB available and caps its container at 112 GiB. The original DeepSeek tensor-parallel service needs all three hosts and cannot coexist with this worker pool.

## Decisions

1. Reuse `scripts/nemotron-spark.sh` unchanged on `spark-e442.local`, `spark-a0a0.local`, and `192.168.1.233`. Preparation is CPU-only and memory-limited. Record private original inspections outside permanent evidence; publish only identity/configuration comparison facts.
2. Map repair, primitive discovery, and composition to workstation loopback ports 18000, 18001, and 18002 through strict authenticated SSH tunnels. No unauthenticated LAN model bind.
3. Use task-local Git roots, isolated OpenCode state/configuration, exact source snapshots and bounded commands. Never share an editable proof checkout between workers. Do not expose host credentials or unrestricted shell access to a model.
4. Repair must preserve public signatures, preconditions, meaningful postconditions, runtime behavior and trust boundaries. A green baseline is not a repair failure: report no actionable defect rather than deleting valid bodies or adding assumptions.
5. Discovery must identify concrete bounded primitives, closest existing APIs, non-duplication evidence and source references. Composition must distinguish proposed finite-model connections from checked proof claims; a proof-only witness uses existing modules without adding trust. Parent integration owns live Trellis changes.
6. Existing production Verus and source-bound checks decide proof acceptance. Research findings are advisory, not solver evidence. Keep unsuccessful attempts and setup limitations visible.
7. Restore the original cluster after the bounded batch, including worker/model failure. Stop only owned replicas, restart original workers before the head, compare Config, HostConfig and mounts by destination, and require an actual DeepSeek completion.
8. Exclude recorded native evidence and byte-for-byte vendored sources from repository formatting. Proof inputs, transcripts, and hash-bound receipts retain the exact bytes used by their original toolchains.

## Acceptance

Three simultaneous real model endpoints and three independently scoped worker sessions; complete baseline and source identities; actual transcripts and role-specific outputs; independent verification of every admitted proof; explicit unchanged/remaining proof boundaries; native lifecycle validation; original DeepSeek identities/configuration and successful inference restored.
