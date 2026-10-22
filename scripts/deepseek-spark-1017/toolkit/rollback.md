# 1017 cutover rollback

The previous deployment (DeepSeek-V4.1-Flash EXL3 3.5 bpw Pollard, abliterated,
TP3 on the three sparks) was **stopped, not removed**. Its containers, weights
and launcher are all still on disk.

## Restore the previous model (≈1 min per node + ~25 min boot)

```sh
# on spark-e442
for h in brittonr@192.168.1.233 dspark-worker local; do
  [ "$h" = local ] && docker start vllm_dsv41 || \
    ssh -n -o BatchMode=yes -i ~/.ssh/dspark-cluster "$h" docker start vllm_dsv41
done
# ready when: curl -s localhost:8888/v1/models | grep deepseek-v4.1-flash
```

`unless-stopped` keeps them running across a reboot, so on the next boot the
*old* model comes back unless the new container replaces the name.

## What the previous deployment was

| item | value |
|---|---|
| container | `vllm_dsv41` on all three nodes (created 2026-09-15, image `vllm-dsv41:exl3a`) |
| weights | `/var/tmp/models/DeepSeek-V4.1-Flash-EXL3-TP3-Ablit` (V4.1 base, 3.5 bpw routed-expert EXL3, `attn.wo_b` abliteration graft on layers 10–35) |
| launcher | `~/dsv41-tp3b-ours.sh` / `~/boot_dsv41_ours.sh` (see `docker inspect vllm_dsv41`) |
| vLLM cache dir | `VLLM_CACHE_ROOT=/cache/vllm-exl3tp3a11-ablit` |
| API | `:8888` on e442, served name `deepseek-v4.1-flash` |

`docker inspect vllm_dsv41` on any node reproduces the exact command line and
environment; the full JSON was also saved at `/var/tmp/models/DeepSeek-V4.1-Flash-EXL3-TP3-Ablit/inspect-*.json`.

## 1017 deployment (this cutover)

| item | value |
|---|---|
| container | `vllm_dsv41` (same name) from `~/dsv41-tp3-1017.sh` |
| weights | `/var/tmp/models/DeepSeek-V4.1-Flash-1017-EXL3-TP3` (native 1017 release + EXL3 2.9 bpw routed experts, stock: **not** abliterated) |
| plan | `settings` file next to this doc: knobs passed to `boot_dsv41_1017.sh` |
| vLLM cache dir | `VLLM_CACHE_ROOT=/cache/vllm-dsv41-1017a` |

Disk: the two packs (485 GB old + 439 GB new) plus their sources (~1.5 TB) are
all still present; delete only after the new deployment has been stable.
