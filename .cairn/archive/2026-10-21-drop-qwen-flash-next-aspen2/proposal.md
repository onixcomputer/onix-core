## Why

`llamacpp-server-qwen38-flash-next-aspen2` cannot start. The IQ4_XS model
with its 32K context asks for 65,159 MiB, while `aspen2` has 62 GiB of memory
and a 48 GiB GTT limit. The unit was already failing before the 2026-10-21
deploy and keeps `aspen2` degraded. The operator chose to drop the service
rather than shrink the model or its context.

## What Changes

- Remove the `qwen38-flash-next-aspen2` llama.cpp instance and its Hugging
  Face token vars.
- Keep `aspen2` in the private mesh as the research provider for the arXiv
  corpus and its Laya instance, with no local inference backend: its
  Mesh-LLM sidecar sets `endpointUrl = null` and declares no backend unit.
- Let the Mesh-LLM module accept a null `endpointUrl`. Such a node renders no
  `openai-endpoint` plugin and must not declare a backend. A node with an
  endpoint still requires an owned backend.
- Update the Mesh-LLM checks: `aspen2` keeps no Qwen unit or token generator
  and renders the research plugin without an OpenAI endpoint, and module
  fixtures cover a research-only node and a backend without an endpoint.

## Impact

- **Files**: `inventory/services/services.ncl`,
  `modules/mesh-llm/schema.ncl`, `modules/mesh-llm/mk-nixos-config.nix`,
  `flake-outputs/_mesh-llm-checks.nix`, and
  `vars/per-machine/aspen2/llamacpp-server-qwen38-flash-next-aspen2-huggingface/`.
- **Risk**: mesh clients lose no working model, because the aspen2 Qwen unit
  was failing. The other mesh nodes render the same configuration.
- **Non-goals**: no change to aspen1's retained Qwen definition, to the
  research services on `aspen2`, or to mesh membership and invites.
- **Testing**: the Mesh-LLM checks, unchanged toplevels for the other
  machines, and an `aspen2` deploy with no failed units, a sidecar with peers,
  and research queries answered through the mesh.

## Affected Specs

- `llm-inference`: the three aspen2 Qwen requirements are removed.
- `mesh-llm-sidecar`: endpoint advertising applies to nodes with a local
  backend, and a research-only node is allowed.
