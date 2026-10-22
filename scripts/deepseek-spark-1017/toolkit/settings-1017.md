# 1017 TP3 deployment settings (recorded at cutover)

Booted by `~/boot_dsv41_1017.sh` on spark-e442 (worker-first: 6d1b, a0a0, e442),
which exports these knobs to `~/dsv41-tp3-1017.sh <rank>` on each node:

| knob | value |
|---|---|
| IMAGE | `vllm-dsv41:exl3a` (local tag on each node: de1580fb368a on e442/a0a0, 008d95698b68 on 6d1b — same vLLM build 8a728663c1c3) |
| MODEL_DIR | `DeepSeek-V4.1-Flash-1017-EXL3-TP3` |
| EXP_NAME | `dsv41-1017a` → `VLLM_CACHE_ROOT=/cache/vllm-dsv41-1017a` |
| GMU / MAXLEN / SEQS / MAX_BATCHED | 0.80 / 300000 / 8 / 4096 |
| EAGER / CUDAGRAPH_MODE | 0 (CUDA graphs) / `FULL_AND_PIECEWISE` |
| SPEC / SPEC_K | `dspark` / 5 |
| ENGRAM_DISK / THREADS / CHUNK | 1 / 32 / 16 |
| TEXT_ONLY / THINKING / PARSERS | 0 (vision on) / false / 1 |
| RUST_FE | 0 |
| VLLM_EXTRA | `--block-size 128 --limit-mm-per-prompt {"image":4} --mm-processor-cache-gb 1 --mm-encoder-tp-mode data` |
| PATCH_NAME | `dsv41-exl3-tp3e` (bind-mounted over the image, unchanged from the V4.1 deployment) |

Same TP=3 / `--nnodes 3` / `--master-port 29541` topology as the deployment it
replaces; API `:8888` on e442, served name `deepseek-v4.1-flash`.
Differences from the old container: model directory, fresh vLLM cache dir, and
`KAI_STACK_SAMPLER` is left off (was a one-off diagnostic).
