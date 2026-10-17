## Context

Three reachable stock-Ubuntu 24.04 Sparks form the existing DeepSeek V4.1 Flash tensor-parallel deployment: head `spark-e442.local` (192.168.1.244), rank 1 `spark-a0a0.local` (192.168.1.234), rank 2 `192.168.1.233` (`spark-6d1b`). Each has ARM64 GB10, driver 580.173.02, 121 GiB unified RAM, and an existing `vllm_dsv41` container using approximately 95 GiB. This is distinct from onix-core's empty production DGX machine inventory.

The user selected public-model-plus-Verus scope and temporary cutover/restoration. The sibling `/home/brittonr/git/OnixResearch/trellis` supplies real proof tasks and its Octet production Verus package; its verifier pin, not the article's historical corpus pin, is appropriate for those tasks.

## Decisions

### Single-Spark, immutable inference

Use NVIDIA's explicitly GB10-supported NVFP4 checkpoint, revision `59b8721646c38111a242da18218859fb2b454322`, and LiLiCorr draft revision `292bf1efc06ba39567da7351f2ad7a522afa3959`. Use the verified Linux ARM64 vLLM image `vllm/vllm-openai@sha256:fd33bec1578f312a01547cc6b9691a5154c3e8bcfb76d2b35acb657bfc4eee8f`. The advertised v0.32.0 tag was unavailable during research; no mutable tag is selected.

Run language-only with context 65536, concurrency one, dflash seven-token drafting, `nemotron_v3` reasoning and `qwen3_coder` tool parsing. Bind `127.0.0.1:8000`; workstation clients use an authenticated SSH tunnel to port 18000. Download exact snapshots before the maintenance window, mount weights read-only, and use a dedicated writable cache. No Hugging Face token or host-home mount is required for these public releases.

### Preserve existing workload ownership

The launcher never stops, removes or rewrites DeepSeek containers. It refuses insufficient free memory rather than overcommitting unified RAM. The first verification temporarily stops all existing ranks, starts the standalone model on the head, then stops only the new model and restarts the original worker containers before the head. Preserve original container identities, mounts, command lines, restart policies, gateways and mesh configuration. No reboot or full-system deployment.

### Reuse Trellis and OpenCode

Use the installed OpenCode client rather than a second agent framework. Copy a self-contained meaningful Trellis proof into a separate work directory, remove a nontrivial proof body, preserve its scaffold, and expose the existing verifier through a bounded local command. Save the failing initial task, transcript, final candidate and independent verifier output. Do not edit Trellis or present the demo's integrity checks as Reasonable's unpublished anti-cheating gate.

Initialize only the temporary task directory as its own Git root. OpenCode 1.18.29 matches file permissions relative to that root, or `/` outside Git; a non-Git task caused exact `proof.rs` reads to be denied. The task-local root permits the intended file without widening access to Trellis or other files.

## Risks / Trade-offs

- NVFP4 stored tensors occupy about 70 GiB before runtime workspace and caches. The current DeepSeek workload cannot coexist with this server; free-memory admission and the temporary cutover are required.
- Spark CUDA kernel/runtime compatibility must be proven by an actual model launch; an ARM64 image manifest alone is insufficient.
- One-Spark inference support does not establish two/three-Spark training support. The published BF16 base alone occupies about 232 GiB; no Spark LoRA-training claim is made.
- Reasonable's article and cited paper do not release the fine-tune, traces or evaluation harness. This change claims only the explicitly approved public-model workflow.

## Primary sources

- https://reasonable.io/blog/post-training-nemotron-3-5-super-vl/
- https://arxiv.org/html/2610.14923v2 (release-status checklist and corpus/toolchain caveats)
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4/blob/59b8721646c38111a242da18218859fb2b454322/README.md
- https://hub.docker.com/v2/repositories/vllm/vllm-openai/tags/nightly-3f1bcfd82bb2e93fcd364fc7a5491718453a77e2
