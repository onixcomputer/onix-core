## Why

DiffusionGemma is running on Aspen1, but the private Mesh-LLM seed still points its primary provider at the old Qwen endpoint. Expose the deployed model through the existing private mesh without opening its direct API or changing other hosts' inference ownership.

## What Changes

- Point Aspen1's primary openai-endpoint plugin at the DiffusionGemma backend on loopback port 8000.
- Replace the mesh sidecar's Qwen dependency with docker-diffusion-gemma.service.
- Preserve the existing Spark provider declaration through a default-empty named extraEndpoints setting, including the original loopback forwarder URL. Reject attempts to shadow the primary endpoint.
- Apply only the selected persistent service closure and restart the Aspen1 mesh sidecar, preserving its identity and join state. Retire the superseded runtime ExecStart override and TOML.

## Impact

- Files: Aspen1 mesh inventory settings, mesh schema/configuration renderer, existing ownership check, obsolete ownership comments, and this native Cairn change.
- Verification: real peer model discovery, non-streaming and streaming generation, seeded read-only canvas log probabilities, unchanged unsupported-parameter errors, private listeners, protected service identities, focused Nix checks and native Cairn validation.
- Boundaries: no public listener, new mesh, credential rotation, model backend restart, whole-host activation or other host/provider settings changes. The structured frontend remains private. The pre-existing externally managed Spark forwarder and merge-proxy script remain untouched.
