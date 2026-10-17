## Why

The user requested three real Nemotron workers across the three Sparks: one repairing current Trellis proof gaps, one searching for new primitives, and one finding compositions of existing proofs. A single GB10 already serves the pinned NVFP4 model, so independent replicas avoid distributing a model that fits locally and use the other two GPUs during the approved temporary DeepSeek cutover.

## What Changes

- Stage the existing immutable launcher, model snapshots, and ARM64 image on all three hosts while DeepSeek remains available.
- Temporarily stop the preserved three-rank DeepSeek deployment, run one loopback-only Nemotron per Spark, and expose three authenticated workstation tunnels.
- Run the installed OpenCode client against three distinct real model endpoints with isolated source snapshots and client state. Keep the current complete production-verifier baseline; do not manufacture missing proofs or misclassify expected negatives as repair targets.
- Preserve actual model/tool transcripts, source-grounded discovery findings, and composition opportunities with an independently checked proof witness where feasible. Integrate only a justified, independently verified, contract-preserving repair; research output does not automatically become production code.
- Stop only owned Nemotron replicas and tunnels, restore all original DeepSeek workers before the head, compare original identities/configurations, and prove restored inference.

## Non-goals

No permanent replacement of DeepSeek, gateway changes, GPU-clock changes, machine inventory enrollment, training or fine-tuning, distributed tensor-parallel Nemotron, new agent framework, or automatic admission of speculative primitives. No change to the existing single-proof demo contract.
