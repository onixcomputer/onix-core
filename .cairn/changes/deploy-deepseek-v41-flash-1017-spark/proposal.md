## Why

The three ARM64 GB10 Sparks (`spark-e442` head, `spark-a0a0`, `spark-6d1b`) serve DeepSeek-V4.1-Flash as one TP3 vLLM deployment (`vllm_dsv41`, API `:8888` on the head) whose weights are an abliterated 3.5 bpw EXL3 pack. The operator asked for DeepSeek's **1017** update (`deepseek-ai/DeepSeek-V4.1-Flash-1017@1bae0e1088993b9b82de08f59de5be5a34e42170`) on the same hardware.

The 1017 checkpoint is a 475 GiB fp8/MXFP4 release with two 101 GiB Engram shards and does not fit two Sparks; the working shape on this fabric is the established TP3 layout with low-bit routed experts and Engram kept on NVMe.

## What Changes

- Stage the 1017 release assets on the head: native shards 1–46 (dense fp8 + MXFP4 experts), the slim non-expert tree, and the two 101 GiB Engram shards fetched as verified byte ranges.
- Splice a TP3 pack from the native slim tensors, the community EXL3 2.9 bpw routed-expert body, and the native Engram shards; verify shard count and load preconditions.
- Replicate the pack to both workers, then cut over worker-first to the 1017 pack while preserving the previous containers for rollback.
- Verify the served OpenAI surface with real completions, record the observed settings and results, and keep a repo-side runbook plus the exercised launcher/cutover tooling.

## Impact

- **Files**: `docs/deepseek-spark.md` (new runbook), `scripts/deepseek-spark-1017/` (launcher, cutover, smoke), this change package with evidence.
- **Risk**: a second ≈439 GB pack plus staging data on each node; the previous pack and its stopped container stay on disk so rollback is a `docker start`. Unified memory is exclusively owned by one vLLM container per node while serving.
- **Non-goals**: no NixOS, Clan, or devenv enrollment (the DGX machine map stays empty), no reboot, no driver or GPU-clock change, no gateway or secret rewrite, no abliteration of the 1017 pack, and no change to `aspen1`'s llama.cpp DeepSeek deployment.
