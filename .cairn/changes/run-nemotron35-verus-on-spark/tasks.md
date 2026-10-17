## Phase 1: Scope and implementation

- [x] [serial] Inspect released assets, all three real Spark workloads, and obtain explicit public-model scope and temporary-cutover decisions. r[onix.nemotron35.scope]
- [x] [serial] Implement and stage the immutable standalone loopback Spark launcher without changing existing workload ownership. r[onix.nemotron35.inference]
- [x] [serial] Reuse Trellis's production verifier and a meaningful proof through an isolated OpenCode workflow without editing Trellis. r[onix.nemotron35.verus]

## Phase 2: Runtime acceptance

- [x] [serial] Launch the public model on a real Spark and exercise reasoning and structured tool calls through the loopback/tunnel API. r[onix.nemotron35.inference]
- [x] [serial] Record a failing initial Trellis obligation and independently verified model-completed proof with unchanged scaffold and no new trust escapes. r[onix.nemotron35.verus]
- [x] [serial] Stop the new model, restore all three original DeepSeek ranks, and verify restored inference before ending the maintenance window. r[onix.nemotron35.restoration]
- [x] [serial] Document observed commands/results and validate the native Cairn change without claiming unavailable training or benchmark reproduction. r[onix.nemotron35.scope]
