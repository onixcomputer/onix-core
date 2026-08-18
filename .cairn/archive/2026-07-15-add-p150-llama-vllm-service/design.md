## Context

The host has two independent Blackhole P150 add-in cards. VibeThinker-3B is an always-on Metalium service on physical card 0; Supra-Router-51M is currently on physical card 1. TT-Metal device ownership prevents an unrelated third process from safely sharing either card, and Tenstorrent's support matrix has no `p150x2` target for two independent P150 add-in cards.

Tenstorrent's getting-started guide recommends `meta-llama/Llama-3.1-8B-Instruct` for p-series add-in cards. The model-specific P150 page identifies the vLLM TT-Metal image `0.18.0-c49bb76-6b4a3a7`, an experimental maximum context of 65,536, and a maximum batch size of 32. Registry inspection resolved the amd64 image to `sha256:6aee48978be401c0a86cb1761c4d64af818df8380bc7b27c1018d704518545ff` and confirmed the image runs as `container_app_user` through `run_vllm_api_server.py`. Direct container mode resolves the bundled model spec from `--model` and `--tt-device`, accepts `--service-port`, reads `HF_TOKEN` from an environment file, and persists `CACHE_ROOT`. Docker exposes only host `/dev/tenstorrent/1`; because that sole node is enumerated as logical device 0 inside the container, the service does not pass the host-oriented `TT_VISIBLE_DEVICES=1` filter.

A five-run CPU trial for the 51M Supra GGUF used four generation/batch workers and preserved the existing output BLAKE3 `c2473faeda8e011b1eec2797d5bf2e047b4e9cf19ec4171709bf824ae2f84014`. It measured 1,031.37 isolated and 778.22 concurrent decode tokens/s. During the synchronized VibeThinker load, VibeThinker retained 19.25 decode tokens/s. This validates CPU Supra as the resource-reallocation mechanism rather than a model removal.

The host has Docker 29.6.1 and both `/dev/tenstorrent/{0,1}` nodes. A supplied Hugging Face token is encrypted through Clan and deployed as a root-only environment file. The model owner approved the account after an initial HTTP 403; the metadata-only preflight now succeeds without exposing the token. A failed gated download left a partial weights directory that the pinned image treated as complete, so startup now removes only model caches whose `config.json` is absent or lacks `model_type`. The completed download and TT compilation occupy 30 GiB and 16 GiB respectively, leaving 452 GiB free.

The initial local activation connection was killed while the transaction restarted core SSH/network services, after it had stopped both existing inference units but before it restarted them. VibeThinker and Supra were manually restored after an 81-second interruption; subsequent activations preserved both start timestamps and zero restart counters. Corrected chat-endpoint probes reproduced both accepted output BLAKE3 values.

The final service became ready on loopback port 8000 after the authorized download and graph compilation. Five fixed Llama requests produced identical BLAKE3 `07b9b4d2ffa9425e9693731677f0f7de4daf6e87e4dc03848f4c0904600e527c`; the first trace-capture request took 56.89 seconds and the four warm requests had a 4.79-second median. A final synchronized test completed VibeThinker, CPU Supra, and Llama requests in 4.10, 1.24, and 30.55 seconds respectively, with the longer Llama result representing its first post-restart trace capture. The synchronized outputs matched accepted VibeThinker and Supra BLAKE3 values and the repeated Llama value. Docker inspection showed only `/dev/tenstorrent/1`, loopback-only port 8000, private cache/log mounts, and no container restart policy; the three systemd services remained active with zero restart counters and no device-lock or fatal-runtime journal matches.

## Success Contract

The exact goal is three simultaneously available model endpoints: VibeThinker on card 0, CPU Supra, and Llama-3.1-8B-Instruct on card 1.

Completion evidence requires:

- VibeThinker's existing unit remains active on port 13305 with `TT_VISIBLE_DEVICES=0`, trace disabled, and unchanged fixed-input output;
- Supra remains active on port 13306 with the CPU llama.cpp package, no Tenstorrent environment/device ownership, the same routing schema/BLAKE3, and median throughput no worse than its former tuned Metalium service;
- the digest-pinned Tenstorrent container owns only `/dev/tenstorrent/1`, serves the exact instruct model on port 8000, returns a valid OpenAI-compatible completion after warmup, and does not expose the Hugging Face token in the Nix store or command line;
- all three requests can complete in one synchronized availability test without `CHIP_IN_USE`, restart loops, or fatal runtime failures; and
- the deployment does not configure undocumented `p150x2` aggregation.

A configured-but-failing container, a time-sharing arrangement that stops VibeThinker, moving VibeThinker off card 0, using mutable image tags, leaking the token, serving base rather than instruct weights, or claiming `p150x2` support are false completion.

Allowed final outcomes are validated, blocked on missing gated-model account authorization, exhausted after a bounded image/runtime failure, or user-decision-required if Tenstorrent's pinned image cannot isolate physical card 1.

## Portfolio Budget

Use the user-provided Tenstorrent guide and support matrix, the model-specific P150 page, one local checkout of `tt-inference-server`, one registry image-contract inspection, and one CPU Supra benchmark family. Bound startup retries to distinct diagnosed failures: container-local device numbering, stale partial weights, and the successful clean retry. Do not download model weights repeatedly, flash firmware, or mutate both existing model services at once.

## Approach Registry

| Family | Mechanism | Claim | Evidence | State |
|---|---|---|---|---|
| CPU router | Run the 51M Supra GGUF on four CPU workers | Frees card 1 while preserving and accelerating routing | Same BLAKE3; 1,031 isolated and 778 concurrent tokens/s | validated |
| Shared card | Start Llama beside an existing Metalium process on one P150 | Three processes can share two cards | TT-Metal device ownership previously produced `CHIP_IN_USE`; no supported sharing contract | falsified |
| Undocumented mesh | Treat two independent P150s as `p150x2` while Vibe uses one | vLLM can aggregate remaining capacity | Support matrix defines p150, p150x4, and p150x8, not this topology | blocked |
| Time sharing | Stop VibeThinker whenever Llama starts | Preserves configuration but not simultaneous availability | Violates the user's supplement-only constraint | falsified |
| CPU Llama | Keep both current card assignments and run 8B on CPU | Adds the endpoint without resource movement | Avoids the supported P150/vLLM path and cannot establish target performance | blocked |
| Free card 1 | CPU Supra plus vLLM Llama on physical card 1 | All three endpoints remain concurrently available | Three synchronized requests completed with stable output hashes, exclusive card-1 mapping, and zero restarts | validated |

## Decisions

### Decision: Preserve VibeThinker as an always-on card-0 service

**Choice:** Do not add conflicts, stop hooks, or replacement behavior to VibeThinker.

**Rationale:** The user explicitly requires supplementation. VibeThinker's existing model, endpoint, trace boundary, and physical card remain untouched.

### Decision: Move only the tiny router to CPU

**Choice:** Change Supra from the Metalium package to CPU llama.cpp with four generation and batch workers.

**Rationale:** Checked output parity and a roughly eightfold isolated throughput gain make this lower-risk than sharing a P150 or time-slicing VibeThinker. The existing endpoint contract remains stable.

### Decision: Pin the official image by digest

**Choice:** Use Tenstorrent's documented vLLM image tag plus the resolved amd64 digest and pass `Llama-3.1-8B-Instruct` with `--tt-device p150`.

**Rationale:** The tag captures the documented tt-metal/vLLM commits; the digest prevents an upstream tag mutation from changing runtime behavior silently.

### Decision: Keep gated credentials out of declarative output

**Choice:** Generate a root-owned clan environment file containing only `HF_TOKEN`, validate placeholders as unset, and pass it with the OCI container's environment-file mechanism.

**Rationale:** The model is gated, but tokens must not enter evaluated Nix text, process arguments, logs, or the Git tree.

### Decision: Respect container-local device numbering

**Choice:** Map only host `/dev/tenstorrent/1` and omit `TT_VISIBLE_DEVICES` from the container environment.

**Rationale:** Docker's exclusive node mapping is the physical isolation boundary. Inside that namespace, card 1 is logical device 0; applying the host identifier again hides the only available accelerator.

### Decision: Repair only provably incomplete weight caches

**Choice:** Before container startup, remove the selected model directory and its symlink only when `config.json` is missing, empty, or lacks `model_type`.

**Rationale:** The pinned image can skip a partial directory left by an interrupted gated download. The narrow check preserves complete weights and TT compilation caches while permitting a clean retry.

## Risks / Trade-offs

- Single-P150 Llama-3.1-8B support is Experimental; successful startup and output do not elevate it to Complete support.
- The official guide requires gated Hugging Face access. A syntactically valid token remains insufficient until its account accepts the model terms; the metadata preflight cleanly blocks unauthorized starts.
- The image is several GiB and model initialization is documented at roughly ten minutes; deployment must use bounded startup/restart behavior.
- Direct device-node selection must be adversarially verified because `--device /dev/tenstorrent` alone exposes both cards; the service must expose only device 1 and ensure the container maps it as the p150 target.
- CPU Supra and VibeThinker share host cores, but the measured synchronized result already includes that contention and substantially exceeds the prior router rate.
