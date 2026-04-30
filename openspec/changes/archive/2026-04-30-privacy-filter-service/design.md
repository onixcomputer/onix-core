## Context

`onix-core` already has schema-driven clan service modules for AI workloads such as `ollama`, `lemonade`, `llm`, `infinity`, and `speaches`. Those modules assume either text generation, embeddings, or speech APIs. `openai/privacy-filter` is different: it is a Hugging Face token-classification model for PII detection/redaction, so it needs a dedicated runtime and API surface instead of being forced through a generative-serving abstraction.

The new service must fit the existing module pattern in this repo:
- add a schema-backed module under `modules/<name>/`
- register it in `modules/default.nix`
- let settings flow through Nickel validation in `inventory/services/settings-contracts.ncl`
- configure instances in `inventory/services/services.ncl`

Operationally, the first deployment target is `aspen1`, but the module should remain reusable for CPU hosts and future AMD GPU hosts. The service also needs a persistent Hugging Face cache so restarts do not re-download large model artifacts.

## Goals / Non-Goals

**Goals:**
- Provide a reusable `privacy-filter` clan service module rather than a one-off machine-specific hack
- Expose a stable local HTTP API for detect/redact operations backed by Hugging Face Privacy Filter
- Support both CPU and AMD GPU deployment modes through module settings
- Reuse the repo's schema-driven inventory validation and service registration patterns
- Default the first service instance to `aspen1`

**Non-Goals:**
- Reusing Ollama, Lemonade, or vLLM APIs for token classification
- Providing a general-purpose Hugging Face model-serving platform for every pipeline type in this change
- Fine-tuning Privacy Filter or changing its label taxonomy
- Public internet exposure; the initial deployment is intended for local/private network consumers

## Decisions

### 1. Add a dedicated `privacy-filter` module

**Choice:** Create `modules/privacy-filter/{default.nix,schema.ncl}` and register it like the existing schema-driven service modules.

**Rationale:** The existing AI modules encode assumptions that do not fit token classification. A dedicated module keeps the service inventory legible, gives us typed settings, and follows the repo's standard module shape.

**Alternatives considered:**
- Extend `llm` with another `serviceType`: rejected because `llm` is oriented around generative APIs and container shapes for Ollama/vLLM.
- Reuse `infinity`: rejected because it is embeddings-specific and would turn this into a misleading abstraction.

**Implementation:** The module will expose settings for state/cache directories, bind host/port, model identifier, device/runtime selection, and extra runtime arguments.

### 2. Serve the model through a small dedicated HTTP runtime

**Choice:** Wrap the Hugging Face model with a narrow HTTP service that exposes explicit `detect`, `redact`, and health/readiness endpoints.

**Rationale:** Privacy Filter's natural interface is token classification plus span decoding, not text generation. A thin service around the model gives downstream callers a stable contract and avoids coupling them to CLI invocation or raw Python internals.

**Alternatives considered:**
- Expose only a CLI: rejected because the repo's managed AI services are service-oriented and callers should not shell into hosts.
- Force an OpenAI-compatible façade: rejected because token classification/redaction does not naturally map to chat/completions semantics.

**Implementation:** The runtime can be packaged either as a small Python service inside the module or as an OCI workload, but the externally visible contract should remain a simple repo-owned HTTP API.

### 3. Keep runtime/device configuration explicit and AMD-friendly

**Choice:** Model/runtime settings will explicitly distinguish model ID, cache path, enableGPU/device selection, and optional runtime overrides rather than baking in one hardware path.

**Rationale:** The first target is `aspen1`, but the module should not assume every deployment is GPU-backed. Explicit device/runtime settings also avoid copying NVIDIA-oriented patterns such as `--gpus=all` into an AMD environment.

**Alternatives considered:**
- Hardcode Aspen ROCm behavior: rejected because it reduces reuse and complicates CPU testing.
- Support GPU implicitly with auto-detection only: rejected because deterministic inventory configuration is easier to operate and review.

**Implementation:** The module schema will include fields for CPU/GPU selection and runtime-specific overrides. The implementation should only attach GPU-specific devices/env when GPU mode is requested.

### 4. Persist Hugging Face artifacts under service state

**Choice:** Store model artifacts under a dedicated persistent state/cache directory managed by tmpfiles and mounted or referenced by the runtime.

**Rationale:** Privacy Filter artifacts are large enough that repeated downloads would waste time and bandwidth. Existing AI modules in the repo already treat model caches as persistent service state.

**Alternatives considered:**
- Stateless downloads on each boot: rejected because it is slow and fragile.
- Shared global cache between unrelated services: rejected for now to keep ownership and rollback simpler.

**Implementation:** The module will manage state/cache directories with correct ownership and make the runtime read/write from that location.

## Risks / Trade-offs

- **Runtime packaging mismatch** → Mitigation: choose one repo-owned runtime path and validate it on `aspen1` before widening scope
- **ROCm support gaps in the chosen runtime stack** → Mitigation: keep CPU mode first-class and treat GPU enablement as a configurable path, not a hard requirement
- **API shape churn for downstream callers** → Mitigation: define detect/redact/health endpoints in the spec before implementation and document them in the module readme/comments
- **Large model startup/download latency** → Mitigation: use persistent cache directories and readiness probes so operators can distinguish startup from failure

## Migration Plan

1. Add the new `privacy-filter` module and schema, and register it in the service module registry.
2. Add the module schema to the settings-validation import registry.
3. Create a `privacy-filter` service instance in `inventory/services/services.ncl` targeting `aspen1` with conservative defaults.
4. Build/evaluate the affected inventory and module outputs locally.
5. Deploy to `aspen1` and verify readiness plus a sample detect/redact request.
6. If rollback is needed, remove or disable the `privacy-filter` service instance and redeploy.

## Open Questions

- Should the first implementation use a repo-packaged Python app directly or an OCI container image built/consumed by Nix?
- Do we want the API to support batch requests in the first version, or only single-text detect/redact calls?
- Should downstream integration with clankers or other local callers be part of a follow-up change rather than this initial deployment?
