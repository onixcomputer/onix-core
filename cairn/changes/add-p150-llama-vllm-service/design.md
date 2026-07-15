## Context

The host has two independent Blackhole P150 add-in cards. VibeThinker-3B is an always-on Metalium service on physical card 0; Supra-Router-51M is currently on physical card 1. TT-Metal device ownership prevents an unrelated third process from safely sharing either card, and Tenstorrent's support matrix has no `p150x2` target for two independent P150 add-in cards.

Tenstorrent's getting-started guide recommends `meta-llama/Llama-3.1-8B-Instruct` for p-series add-in cards. The model-specific P150 page identifies the vLLM TT-Metal image `0.18.0-c49bb76-6b4a3a7`, an experimental maximum context of 65,536, and a maximum batch size of 32. Registry inspection resolved the amd64 image to `sha256:6aee48978be401c0a86cb1761c4d64af818df8380bc7b27c1018d704518545ff` and confirmed the image runs as `container_app_user` through `run_vllm_api_server.py`. The source checkout confirms that direct container mode resolves the bundled model spec from `--model` and `--tt-device`, accepts `--service-port`, reads `HF_TOKEN` from an environment file, persists `CACHE_ROOT`, and implements `--device-id 1` by mapping only `/dev/tenstorrent/1` into the container.

A five-run CPU trial for the 51M Supra GGUF used four generation/batch workers and preserved the existing output BLAKE3 `c2473faeda8e011b1eec2797d5bf2e047b4e9cf19ec4171709bf824ae2f84014`. It measured 1,031.37 isolated and 778.22 concurrent decode tokens/s. During the synchronized VibeThinker load, VibeThinker retained 19.25 decode tokens/s. This validates CPU Supra as the resource-reallocation mechanism rather than a model removal.

The host has Docker 29.6.1, both `/dev/tenstorrent/{0,1}` nodes, and 506 GiB free on the root/docker filesystem. No local Hugging Face token is currently available, so gated model download and final runtime proof remain explicitly blocked until that secret is supplied.

## Success Contract

The exact goal is three simultaneously available model endpoints: VibeThinker on card 0, CPU Supra, and Llama-3.1-8B-Instruct on card 1.

Completion evidence requires:

- VibeThinker's existing unit remains active on port 13305 with `TT_VISIBLE_DEVICES=0`, trace disabled, and unchanged fixed-input output;
- Supra remains active on port 13306 with the CPU llama.cpp package, no Tenstorrent environment/device ownership, the same routing schema/BLAKE3, and median throughput no worse than its former tuned Metalium service;
- the digest-pinned Tenstorrent container owns only `/dev/tenstorrent/1`, serves the exact instruct model on port 8000, returns a valid OpenAI-compatible completion after warmup, and does not expose the Hugging Face token in the Nix store or command line;
- all three requests can complete in one synchronized availability test without `CHIP_IN_USE`, restart loops, or fatal runtime failures; and
- the deployment does not configure undocumented `p150x2` aggregation.

A configured-but-failing container, a time-sharing arrangement that stops VibeThinker, moving VibeThinker off card 0, using mutable image tags, leaking the token, serving base rather than instruct weights, or claiming `p150x2` support are false completion.

Allowed final outcomes are validated, blocked on the missing gated-model credential, exhausted after a bounded image/runtime failure, or user-decision-required if Tenstorrent's pinned image cannot isolate physical card 1.

## Portfolio Budget

Use the user-provided Tenstorrent guide and support matrix, the model-specific P150 page, one local checkout of `tt-inference-server`, one registry image-contract inspection, one CPU Supra benchmark family, and at most two container startup attempts after the credential exists. Do not download model weights repeatedly, flash firmware, or mutate both existing model services at once.

## Approach Registry

| Family | Mechanism | Claim | Evidence | State |
|---|---|---|---|---|
| CPU router | Run the 51M Supra GGUF on four CPU workers | Frees card 1 while preserving and accelerating routing | Same BLAKE3; 1,031 isolated and 778 concurrent tokens/s | validated |
| Shared card | Start Llama beside an existing Metalium process on one P150 | Three processes can share two cards | TT-Metal device ownership previously produced `CHIP_IN_USE`; no supported sharing contract | falsified |
| Undocumented mesh | Treat two independent P150s as `p150x2` while Vibe uses one | vLLM can aggregate remaining capacity | Support matrix defines p150, p150x4, and p150x8, not this topology | blocked |
| Time sharing | Stop VibeThinker whenever Llama starts | Preserves configuration but not simultaneous availability | Violates the user's supplement-only constraint | falsified |
| CPU Llama | Keep both current card assignments and run 8B on CPU | Adds the endpoint without resource movement | Avoids the supported P150/vLLM path and cannot establish target performance | blocked |
| Free card 1 | CPU Supra plus vLLM Llama on physical card 1 | All three endpoints remain concurrently available | CPU route validated; image/device runtime awaits gated token | active |

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

## Risks / Trade-offs

- Single-P150 Llama-3.1-8B support is Experimental; successful startup and output do not elevate it to Complete support.
- The official guide requires gated Hugging Face access. Without a supplied token, final download and runtime validation are blocked rather than simulated.
- The image is several GiB and model initialization is documented at roughly ten minutes; deployment must use bounded startup/restart behavior.
- Direct device-node selection must be adversarially verified because `--device /dev/tenstorrent` alone exposes both cards; the service must expose only device 1 and ensure the container maps it as the p150 target.
- CPU Supra and VibeThinker share host cores, but the measured synchronized result already includes that contention and substantially exceeds the prior router rate.
