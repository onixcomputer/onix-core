## Why

Britton-desktop's Underclass pool holds three enrolled Codex subscriptions, but only local OMP and Aspen3's SSH tunnel can use it. The private Mesh-LLM network cannot: Mesh-LLM 0.72.2 probes and forwards external endpoints without credentials and always as chat completions, while Underclass requires its proxy key and its Codex backend accepts only streamed Responses requests (`Unsupported parameter: messages`, `Stream must be set to true`). Separately, a second named `openai-endpoint` entry never loads, because the pinned plugin always reports its default name.

## What Changes

- Add `underclass-mesh-gateway`, a stdlib-only loopback service that reads the proxy key from a systemd credential, advertises the Codex-backed catalog and translates chat completions to streamed Responses and back, including tool calls, usage and finish reasons.
- Enable it on britton-desktop through the existing `omp-agents` instance on loopback port 18081, and register it as the desktop sidecar's named `underclass` endpoint.
- Patch the pinned openai-endpoint 0.1.2 plugin to report the host-assigned `MESH_LLM_PLUGIN_NAME`, so every named extra endpoint loads.
- Activate only the gateway and the desktop mesh sidecar; no whole-host switch.

## Impact

- **Files**: `pkgs/underclass-mesh-gateway/`, `flake-outputs/tools.nix`, `modules/llm-agents/schema.ncl`, `modules/llm-agents/underclass.nix`, `inventory/services/services.ncl`, `pkgs/mesh-llm/default.nix`, `patches/openai-endpoint-plugin-name.patch`, `AGENTS.md` and this change.
- **Testing**: gateway translation and HTTP tests in the package build, `mesh-llm-sidecars` and `llm-agents-omp-*` checks, selected and unselected machine evaluation, a direct gateway smoke against live Underclass, and remote-peer inference through the mesh.
