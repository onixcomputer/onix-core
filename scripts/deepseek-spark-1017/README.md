# DeepSeek-V4.1-Flash-1017 on the three GB10 Sparks

Exercised tooling for the TP3 rollout documented in
[`docs/deepseek-spark.md`](../../docs/deepseek-spark.md) and tracked by
[`.cairn/changes/deploy-deepseek-v41-flash-1017-spark`](../../.cairn/changes/deploy-deepseek-v41-flash-1017-spark).

| Path | Purpose |
| --- | --- |
| `boot_dsv41_1017.sh` | Head orchestrator; exports the recorded knobs and boots ranks worker-first (6d1b, a0a0, e442). |
| `dsv41-tp3-1017.sh` | Per-rank launcher invoked by the orchestrator on each node (rank 0 = head, 1 = a0a0, 2 = 6d1b). |
| `toolkit/build_all.sh` | Waits for the staged downloads, finalizes the slim tree, splices the TP3 pack, and resumes per shard. |
| `toolkit/fetch_release_slim.py` | Fetches the pinned native 1017 release shards and writes the expert-stripped slim tree. |
| `toolkit/fetch_engram_chunks.sh` | Fetches the two 101 GiB Engram shards as verified byte-range parts; assembles only after LFS sha256 matches. |
| `toolkit/build_tp3_pack.py` | Splices slim + EXL3 routed-expert body + native Engram into the pack the launcher serves. |
| `toolkit/verify_pack_full.py` | Byte-verifies every tensor of the spliced pack against its three sources. |
| `toolkit/sync_to_workers.sh` | Resumable replication of the pack to `spark-a0a0` and `spark-6d1b`. |
| `toolkit/cutover.sh` | Stops the previous containers worker-first, boots the 1017 deployment, and waits for the API. |
| `toolkit/smoke_1017.py` | Post-boot real-completion and needle smoke test against `:8888`. |
| `toolkit/flush_cache.py`, `toolkit/prestop/` | Userspace page-cache flush and the recorded pre-cutover state of the head. |
| `toolkit/settings-1017.md`, `toolkit/rollback.md` | The knobs passed at boot and the exact rollback procedure. |

The pack's routed experts come from the community EXL3 2.9 bpw body
(`LibertAIDAI/DeepSeek-V4.1-Flash-1017-EXL3-2.9bpw`, MIT); everything else is the
pinned native release `deepseek-ai/DeepSeek-V4.1-Flash-1017@1bae0e1088993b9b82de08f59de5be5a34e42170`.
Both packs stay on disk; the previous abliterated deployment is preserved as a
stopped container so rollback is `docker start vllm_dsv41` on all three nodes.
