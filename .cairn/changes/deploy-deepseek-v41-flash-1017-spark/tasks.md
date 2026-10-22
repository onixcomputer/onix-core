## Phase 1: Stage 1017 assets on the head

- [x] [serial] Fetch the pinned native release shards 1–46 and the slim non-expert tree for `1bae0e1088993b9b82de08f59de5be5a34e42170`. r[onix.spark.deepseek1017.pack]
- [ ] [serial] Fetch both 101 GiB Engram shards as verified byte-range parts and assemble them only after LFS sha256 verification. r[onix.spark.deepseek1017.pack]
- [ ] [serial] Download the EXL3 2.9 bpw routed-expert body and confirm its shard set before splicing. r[onix.spark.deepseek1017.pack]

## Phase 2: Build and replicate the TP3 pack

- [ ] [serial] Finalize the slim tree and splice the TP3 pack from slim + EXL3 body + native Engram, with per-shard verification. r[onix.spark.deepseek1017.pack]
- [ ] [serial] Verify the pack load preconditions (shard set, index, config) on the head before any cutover. r[onix.spark.deepseek1017.pack]
- [ ] [serial] Replicate the pack to `spark-a0a0` and `spark-6d1b` resumably and confirm sizes match the head. r[onix.spark.deepseek1017.pack]

## Phase 3: Cutover and serving acceptance

- [ ] [serial] Record the previous container identities (id, image, `Config`, `HostConfig`, mounts) as rollback evidence before stopping anything. r[onix.spark.deepseek1017.cutover]
- [ ] [serial] Stop the previous containers (workers first) and boot the 1017 launcher worker-first, waiting for the API rather than a fixed sleep. r[onix.spark.deepseek1017.cutover]
- [ ] [serial] Confirm `/v1/models` names the 1017 pack root and exercise a real completion with recorded usage. r[onix.spark.deepseek1017.serving] r[onix.spark.deepseek1017.verification]
- [ ] [serial] Record the settings actually passed at boot and the pack/rollback identities in this change's evidence. r[onix.spark.deepseek1017.verification]

## Phase 4: Repository record

- [ ] [serial] Add the observed runbook and exercised launcher/cutover/smoke tooling to the repository. r[onix.spark.deepseek1017.serving]
- [ ] [serial] Validate the native Cairn change and retain the recorded evidence without claiming benchmark reproduction. r[onix.spark.deepseek1017.verification]
