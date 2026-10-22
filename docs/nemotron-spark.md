# Nemotron 3.5 on the stock-Ubuntu Sparks

## Scope and ownership

This runs NVIDIA's public **Nemotron 3.5 Super VL 120B/A12B NVFP4**, language-only, as one independent replica per ARM64 GB10 Spark. Workstation OpenCode clients use authenticated SSH tunnels. The single-proof demonstration below repairs a real Trellis Verus proof; the three-worker layout separates current-corpus repair, primitive discovery, and proof composition. It is not Reasonable's unreleased fine-tune, training pipeline, anti-cheating harness, or a reproduction of its benchmark score.

The current three-Spark DeepSeek V4.1 deployment owns the GPUs. Nemotron cannot coexist with its approximately 95 GiB per-rank allocation. Use an explicitly scheduled temporary cutover, then restore the original containers. These are stock Ubuntu hosts, not entries to add to the empty onix-core DGX machine inventory. No Clan/devenv deployment, reboot, GPU-clock change, gateway rewrite, or model-service replacement is needed.

| Role | SSH target | Existing container |
| --- | --- | --- |
| Head; Nemotron acceptance target | `brittonr@spark-e442.local` | `vllm_dsv41` |
| DeepSeek rank 1 | `brittonr@spark-a0a0.local` | `vllm_dsv41` |
| DeepSeek rank 2 (`spark-6d1b`) | `brittonr@192.168.1.233` | `vllm_dsv41` |

## Pinned runtime

[`scripts/nemotron-spark.sh`](../scripts/nemotron-spark.sh) pins:

- Linux ARM64 vLLM image: `vllm/vllm-openai@sha256:fd33bec1578f312a01547cc6b9691a5154c3e8bcfb76d2b35acb657bfc4eee8f` (observed vLLM `0.32.0rc1.dev190+g3f1bcfd82`).
- Base: `nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4@59b8721646c38111a242da18218859fb2b454322`.
- LiLiCorr draft: `nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4-LiLiCorr@292bf1efc06ba39567da7351f2ad7a522afa3959`.

The launcher uses 65,536-token context, concurrency one, dflash seven-token drafting, FlashInfer Mamba, `nemotron_v3` reasoning, and `qwen3_coder` tool parsing. It binds **only `127.0.0.1:8000`**, mounts both snapshots read-only, limits container memory to 112 GiB with no additional swap, and requires at least 100 GiB `MemAvailable` before launch. It never stops another workload.

Prerequisites on the Spark: the working NVIDIA driver/container toolkit, Docker access, Bash, `flock`, `ss`, and disk space for the image and approximately 70 GiB of base tensors plus draft and caches. The accepted host had driver `580.173.02` and 121 GiB unified RAM. No Hugging Face credential is needed. Download containers are CPU-only and memory-limited.

## Prepare before taking GPUs offline

Run from this repository:

```sh
ssh brittonr@spark-e442.local 'mkdir -p /home/brittonr/.local/share/onix-nemotron35'
scp scripts/nemotron-spark.sh brittonr@spark-e442.local:/home/brittonr/.local/share/onix-nemotron35/nemotron-spark.sh
ssh brittonr@spark-e442.local 'bash /home/brittonr/.local/share/onix-nemotron35/nemotron-spark.sh prepare'
```

`prepare` pulls the immutable image and downloads complete exact snapshots. A snapshot is reusable only after the successful-download marker is written. It does not use the GPUs or mount the host home/credentials. State lives under `${XDG_DATA_HOME:-$HOME/.local/share}/onix-nemotron35`; keep that location consistent across commands.

## Temporary cutover and API access

First inspect and record the current three containers, including IDs, images, configuration and restart policies. Do not remove, recreate, or update them. Only in the approved maintenance window, stop the original head and then both workers:

```sh
ssh brittonr@spark-e442.local 'docker stop --timeout 60 vllm_dsv41'
ssh brittonr@spark-a0a0.local 'docker stop --timeout 60 vllm_dsv41'
ssh brittonr@192.168.1.233 'docker stop --timeout 60 vllm_dsv41'
ssh brittonr@spark-e442.local 'bash /home/brittonr/.local/share/onix-nemotron35/nemotron-spark.sh start'
```

The launcher refuses an existing named Nemotron container, occupied TCP port 8000, or insufficient memory. A running container is **not** API readiness. Observe startup:

```sh
ssh brittonr@spark-e442.local 'docker logs --follow onix-nemotron35'
```

The first accepted startup took about 12 minutes to load/compile. Wait for application startup, then check the API; do not infer readiness from a fixed sleep.

In a separate workstation terminal, keep this authenticated tunnel open:

```sh
ssh -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:18000:127.0.0.1:8000 brittonr@spark-e442.local
```

```sh
curl --fail http://127.0.0.1:18000/v1/models
```

The served model ID is `nemotron-3.5-super-vl`. Use the OpenAI-compatible base URL `http://127.0.0.1:18000/v1`; reasoning is enabled through `chat_template_kwargs.enable_thinking`. Never expose the unauthenticated API on a public/LAN bind.

## Run the real Trellis proof session

The workstation needs Python 3, Bash, Git, Nix, and OpenCode (acceptance client: `1.18.29`), plus the sibling Trellis checkout and access to its existing `.#verus` package:

```sh
bash scripts/nemotron-verus.sh \
  --trellis /home/brittonr/git/OnixResearch/trellis \
  --endpoint http://127.0.0.1:18000/v1 \
  --output /tmp/nemotron-verus-session
```

Choose a new or empty output directory, outside Trellis. Omitting `--output` allocates a temporary directory and prints its path. The default Trellis path is the sibling `../OnixResearch/trellis`.

The runner copies `src/seq_fold.rs`, checks the original, removes only `count_matching_all_from`'s induction body, and confirms the resulting postcondition fails. OpenCode can read/edit only `proof.rs` and run the no-argument `./verify` wrapper. A fresh Git root keeps OpenCode's worktree-relative permission matching local to this task; client state/configuration are isolated from the user's normal OpenCode setup. The session is limited to 24 steps/30 minutes; verifier calls have a two-minute timeout.

Independent final verification requires an actually changed proof, identical frozen scaffold, the restricted proof-language policy, and a successful run of **Trellis's production Verus**, not an agent's success claim. The expected module result is `8 verified, 0 errors`; the removed-proof preflight produced `7 verified, 1 error`. Trellis itself is never edited. The earlier Bloom task was unsuitable for its current production verifier because of old mutable-reference syntax, so this workflow uses the compatible sequence-induction theorem instead.

Artifacts include `unsolved.rs`, `unsolved-verifier.log`, `transcript.jsonl`, `work/proof.rs`, `final-verifier.log`, and `result.json`. Only `result.json` with `verified: true`, backed by the final log, establishes completion. These checks and OpenCode permissions are a bounded demonstration, **not an adversarial OS sandbox or Reasonable's unpublished evaluation gate**.

## Three independent workers

Prepare the same pinned launcher and complete snapshots on **all three hosts before stopping DeepSeek**. After the head and both original workers have stopped, run the launcher's `start` command on each host. Each replica has its own weights/cache and concurrency-one server; this is three independent models, not a tensor-parallel model.

| Worker | Spark | Workstation OpenAI base URL |
| --- | --- | --- |
| Current-corpus repair | `spark-e442.local` | `http://127.0.0.1:18000/v1` |
| Primitive discovery | `spark-a0a0.local` | `http://127.0.0.1:18001/v1` |
| Proof composition | `192.168.1.233` | `http://127.0.0.1:18002/v1` |

Use the authenticated tunnel command above with the corresponding host and local port; the remote destination remains `127.0.0.1:8000`. Require an actual completion from each model before releasing the worker batch. All three hosts passed simultaneous real completions with the pinned runtime.

Each OpenCode process needs a separate Git-root source snapshot, client state/configuration, and role-specific permissions. Repair and composition use fixed, no-argument production-Verus commands; discovery is read-only. Do not share an editable checkout or accept a model's claimed verification result. A green repair baseline must remain green: inspect meaningful contract/trust gaps without deleting valid proof bodies. Discovery proposals remain advisory, and a checked composition witness establishes only its explicit finite-model contract against its frozen dependencies.

### Observed three-worker campaign (2026-10-17)

- **Inference and isolation:** all three pinned replicas returned overlapping real completions. The independent OpenCode workers used separate source snapshots and client state. The complete frozen production-Verus baseline was **11,146 verified, 0 errors**, with 810 Rust source files inventoried.
- **Repair:** no source repair was admitted in this three-worker campaign. An actual runtime consumer reproduced a `snapshot_integrity` collision: changing metadata from `0` to `1 << 63` leaves `dual_hash(0, metadata)` equal to zero, and both integrity checks accept the tampered record. This exposed a trust/implementation gap, repaired in the subsequent run below; a green solver result under trusted axioms does not establish runtime collision resistance or axiom consistency. The version-comparison fallback also remains outside the admitted finite-model comparison proof.
- **Primitive discovery:** none of the three proposed primitives survived review. Retry-context and dedup-window novelty was not substantiated; the carryover-quota proposal admitted `used = 101` with a declared limit of `100`. Both original and corrected model findings are retained; this is not a claim that the corpus has no other opportunities.
- **Composition:** the actual model produced a proof that causal readiness implies a strict vector-clock advance **after merging** local and message clocks, for arbitrary equal-length finite clocks and a valid sender. Independent production Verus checked both proofs and their complete five-module dependency closure: **69 verified, 0 errors**, without new domain trust escapes. A runtime consumer exercised readiness, merge, locally-ahead nonsender counters, and exhausted-sender rejection. The accepted witness remains a research artifact, not a production-exported API or distributed-protocol guarantee.
- **Restoration:** all three original DeepSeek container IDs, images, `Config`, `HostConfig`, and destination-keyed mount definitions matched. Both workers restarted before the head, and the restored head returned `42` for `6 × 7`. All owned replicas, tunnels, and log followers were closed.
- **Source scope:** the final identity guard found four changed documentation/manifest inputs; all 810 frozen Rust source files still matched. Those edits were left intact. The baseline is attributed to the frozen campaign snapshot, not blanket validation of the subsequently changed workspace.

The [native campaign evidence](../.cairn/changes/run-three-nemotron-proof-workers/evidence/) retains every real model attempt, failed and successful solver receipts, rejected findings, the accepted composition witness, parent runtime checks, final source identities, and restoration proof.

### Snapshot-integrity repair (2026-10-17)

- **Actual model attempt:** a bounded pinned Nemotron worker used an isolated snapshot and an exact three-file edit allowlist. Both of its verifier calls failed; its final candidate was not independently verified and had removed required Tracey markers. The attempt and candidate are retained, not credited as an accepted autonomous repair.
- **Accepted correction:** the independently corrected implementation uses an allocation-free `u128` pair commitment: data in the low 64 bits, metadata in the high 64 bits. The executable bridge and full-domain injectivity are proved without replacement trust. `SnapshotIntegrity.combined_hash` is now `u128`; `combine_hashes`, `combine_hashes_spec` and `combine_hashes_injective` replace the retired `dual_hash*` API. Active consumer proofs/tests and trust accounting were migrated.
- **Independent acceptance:** complete production Verus reports **11,148 verified, 0 errors**. Cargo passes **5,226 library tests** plus its binary and documentation tests. Tracey reports **0 uncovered and 0 untested out of 2,270 requirements**. The runtime consumer checks 16 boundary pairs, rejects 2,048 independent component changes and 2,048 commitment-bit changes, and rejects the original high-bit collision through both integrity entry points. The real replication regression failed before the repair and passes afterward.
- **Claim boundary:** the remaining explicit trusted-boundary count is **13**, down from 15. This commitment binds supplied hashes exactly; it is not a cryptographic hash, payload authenticator, wire codec, or proof that upstream hashes resist collisions. Recomputing a matching commitment can produce another valid record. The version fallback and remaining trust boundaries are unchanged.
- **Restoration:** the owned replica was stopped and removed, the tunnel was closed, and all three original DeepSeek containers matched their recorded IDs, images, `Config`, `HostConfig` and destination-keyed mounts. The restored head returned `42`. No persistent Spark configuration was changed.

The [native repair evidence](../.cairn/archive/2026-10-21-repair-trellis-snapshot-integrity/evidence/) retains the actual model transcript, rejected candidate, failed-before consumer receipt, source identities, runtime/proof results, recovered local-tool failures and restoration proof.

### Unrestricted Nix version comparison (2026-10-17)

- **Actual model attempt:** the pinned replica served a real bounded OpenCode worker. The client ended with `ContextOverflowError` after oversized source reads, without changing either allowlisted source file. A separate parent check selected the nonexistent `properties` module; that failed invocation is retained but is not evidence about model proof quality. No autonomous repair is credited.
- **Accepted correction:** the independent implementation accepts arbitrary byte vectors, consumes punctuation/NUL/high bytes, handles exact `pre` precedence, and matches the inspected Linux C-locale Nix profile. Numeric classification uses Nix's signed-32-bit value bound, unlimited leading zeros and lexical overflow behavior—not an input-length cap or saturating parser. The executable remains iterative and allocation-free; finite admission APIs and the trusted fallback are removed.
- **External runtime evidence:** the actual comparator agreed with the pinned Nix 2.36.0 library on **6,322 byte-vector pairs** and with `builtins.compareVersions` on **3,279 representable pairs**, with no mismatches. NUL/non-UTF8 cases were checked through the native library, not claimed as JSON-evaluator equivalence. This is evidence for the recorded binaries/libraries and C locale, not all C++ signed-char/libc profiles.
- **Independent acceptance:** final-source production Verus reports **11,143 verified, 0 errors**. Cargo passes **5,228 library tests**, 52 binary tests and 9 documentation tests; strict Clippy passes on all targets. Tracey reports **0 uncovered and 0 untested out of 2,270 requirements**. The current source inventory is **12 trusted sites across four files** (seven executable bridges and five proof assumptions), down from 13, without replacement trust.
- **Repository-wide limitation:** the complete verifier command is not green: immutable UCAN manifest/release-profile checks reject existing working-tree identity drift, including the prospective licensing change. Those recorded release identities remain untouched. The successful full production proof run uses the configured `--rlimit 20 --triggers-mode silent` profile; earlier direct invocations and their resource-limit failures remain in the evidence.
- **Restoration:** the owned replica and tunnel were closed. All three original DeepSeek containers matched their recorded IDs, images, `Config`, `HostConfig` and destination-keyed mounts; the restored head returned `42`. No persistent Spark configuration changed.

The [native Nix repair evidence](../.cairn/archive/2026-10-21-repair-trellis-nix-version/evidence/) separates the actual model failure from the independent correction, before/after runtime failures, exact oracle identities and source-bound acceptance. Trellis retains a standalone acceptance bundle in `.cairn/changes/verify-unrestricted-nix-version/evidence/`.

## Restore DeepSeek after the session, including failure

Stop every owned Nemotron replica, then restart the preserved workers before the head. The two additional stop commands apply to three-worker mode:

```sh
ssh brittonr@spark-e442.local 'bash /home/brittonr/.local/share/onix-nemotron35/nemotron-spark.sh stop'
ssh brittonr@spark-a0a0.local 'bash /home/brittonr/.local/share/onix-nemotron35/nemotron-spark.sh stop'
ssh brittonr@192.168.1.233 'bash /home/brittonr/.local/share/onix-nemotron35/nemotron-spark.sh stop'
ssh brittonr@spark-a0a0.local 'docker start vllm_dsv41'
ssh brittonr@192.168.1.233 'docker start vllm_dsv41'
ssh brittonr@spark-e442.local 'docker start vllm_dsv41'
```

`stop` checks ownership and addresses the inspected container ID, not just its name. Downloads/caches remain available for another maintenance window. Confirm that all original IDs, images, configuration and restart policies match the recorded values. Check the original DeepSeek endpoint and perform an actual completion before declaring restoration complete; `/v1/models` alone is insufficient. Close the temporary tunnel/log-following processes when finished.

The current DeepSeek head listens on `http://127.0.0.1:8888/v1`, distinct from Nemotron's port 8000. Compare mount definitions by destination, not array position: Docker reordered otherwise identical mount arrays on restart.

## Observed acceptance (2026-10-17)

- The pinned model served on `spark-e442.local` through the loopback tunnel and returned a correct answer with a separate reasoning field (86 reasoning tokens in the recorded short API request).
- The real OpenCode session completed `read`, `bash`, `edit`, and `bash` tool calls. The removed induction proof failed its postcondition (`7 verified, 1 error`); the generated replacement independently passed (`8 verified, 0 errors`). Trellis's source and toolchain-lock hashes remained unchanged.
- Nemotron was stopped and removed. All three original DeepSeek container IDs, images, restart policies, `Config`, `HostConfig`, and mount definitions were preserved. The restored head on port 8888 answered `6 × 7` with `42`.
- Ruff formatting/lint, Bash syntax checks, and native Cairn validation passed. The native change retains the actual model response, proof transcript, before/after proof files, verifier logs, and restoration evidence.

The validation used the canonical local Cairn checkout through Nix's Git fetcher:

```sh
nix run git+file:///home/brittonr/git/OnixResearch/cairn#cairn -- validate \
  --root /home/brittonr/git/onix-core \
  --policy /home/brittonr/git/OnixResearch/cairn/cairn-policy/generated/cairn-policy.json
```

The documented shorter checkout path is a symlink rejected by the `path:` fetcher; using the real directory with `path:` also encountered an unsupported socket. The local Git fetcher avoids both without changing the Cairn checkout or its runtime files.

## Sources and evidence

- [Reasonable article](https://reasonable.io/blog/post-training-nemotron-3-5-super-vl/) and [paper release-status discussion](https://arxiv.org/html/2610.14923v2).
- [NVIDIA's pinned NVFP4 model card](https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4/blob/59b8721646c38111a242da18218859fb2b454322/README.md).
- [OpenCode permissions](https://opencode.ai/docs/permissions/): exact worktree-relative file allowlists, not unrestricted agent approval.
- Native change and recorded acceptance artifacts: [`.cairn/changes/run-nemotron35-verus-on-spark`](../.cairn/changes/run-nemotron35-verus-on-spark/).
- Three-worker campaign, frozen inputs, and actual endpoint evidence: [`.cairn/changes/run-three-nemotron-proof-workers`](../.cairn/changes/run-three-nemotron-proof-workers/).
- Snapshot-integrity repair and independent acceptance: [`.cairn/archive/2026-10-21-repair-trellis-snapshot-integrity`](../.cairn/archive/2026-10-21-repair-trellis-snapshot-integrity/).
- Unrestricted Nix comparison and independent acceptance: [`.cairn/archive/2026-10-21-repair-trellis-nix-version`](../.cairn/archive/2026-10-21-repair-trellis-nix-version/).
