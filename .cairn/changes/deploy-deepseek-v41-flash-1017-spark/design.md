# 1017 Spark rollout

## Topology

| Role | Host | Address | Service |
| --- | --- | --- | --- |
| head (rank 0) | `spark-e442.local` | 192.168.1.244 (RoCE `enp1s0f1np1` 10.44.0.1) | `vllm_dsv41`, API `:8888`, master `:29541` |
| worker (rank 1) | `spark-a0a0.local` | 192.168.1.234 (RoCE 10.44.0.2) | `vllm_dsv41 --headless` |
| worker (rank 2) | `spark-6d1b` | 192.168.1.233 | `vllm_dsv41 --headless` |

One GB10 per node (121 GiB unified), so TP3 spans three hosts over the LAN/`enP7s7`
sockets; NCCL runs with `NCCL_NET=Socket` (`NCCL_IB_DISABLE=1`) because the RoCE path
is not used by this deployment.

## Pack provenance and build

The served directory is `/var/tmp/models/DeepSeek-V4.1-Flash-1017-EXL3-TP3`, spliced
from three sources by `build_tp3_pack.py`:

1. **Native release non-expert tensors** (`deepseek-ai/DeepSeek-V4.1-Flash-1017` at
   `1bae0e1088993b9b82de08f59de5be5a34e42170`), slimmed per shard by dropping the
   routed-expert tensors.
2. **Routed experts at EXL3 2.9 bpw** from the community body pack
   (`LibertAIDAI/DeepSeek-V4.1-Flash-1017-EXL3-2.9bpw`) — stock, not abliterated.
3. **Engram tables** restored from the native release's two 101 GiB shards, fetched
   as 64 verified byte-range parts each and assembled only after LFS sha256 checks.

The staged tree keeps the native download, the slim tree, the body, and the Engram
shards under `/var/tmp/models/DeepSeek-V4.1-Flash-1017-EXL3-2.9bpw/` so an
interrupted build resumes per shard rather than re-downloading.

## Runtime settings

Observed knobs recorded at cutover in `.cairn/changes/…/evidence/settings.json`:
`GMU 0.80`, `MAXLEN 300000`, `SEQS 8`, `MAX_BATCHED 4096`, CUDA graphs
`FULL_AND_PIECEWISE`, DSpark speculative decoding with `k=5`, Engram on disk
(`DSV41_ENGRAM_DISK=1`, 32 threads, chunk 16), vision enabled with
`--block-size 128 --limit-mm-per-prompt {"image":4}`, and the `dsv41-exl3-tp3e`
Python patch overlay mounted read-only over the image.

## Cutover and rollback

`cutover.sh` stops the old container on rank 2, then rank 1, then the head (stop, never
remove), boots the 1017 launcher worker-first, and waits for `/v1/models`. Because the
old containers keep `--restart unless-stopped`, rollback is `docker start vllm_dsv41`
on all three nodes and takes about one boot cycle. Weights for both packs stay on disk
until the new deployment has been stable.

## Verification

Slice checks, not a single green light:

- Pack preconditions before boot: 48 shards, `config.json`, index, and the head's
  memory admission gate (≥ 100 GiB `MemAvailable`) — the launcher refuses otherwise.
- The API identity must name the 1017 pack root, not the previous pack.
- Real completions through `:8888` (arithmetic and instruction-following), plus the
  served model listing and usage accounting.
- The previous pack's container identities stay recorded so rollback remains exact.
