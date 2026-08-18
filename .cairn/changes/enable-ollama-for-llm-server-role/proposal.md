## Why

The active `llm` service inventory selects `serviceType = "ollama"`, but the generic LLM module only defines a systemd service for vLLM. In Ollama mode it installs a client package and opens the configured firewall port without enabling an Ollama server or pulling the requested models.

## What Changes

- Make the LLM server role instantiate a managed Ollama service when Ollama is selected.
- Apply the configured host, port, GPU policy, and model list to that service.
- Open the firewall only when the effective bind address requires remote access.
- Fail evaluation for declared service types that have no implemented backend instead of silently doing nothing.
- Add focused evaluation tests for Ollama, vLLM, local-only binding, and unsupported backends.

## Impact

- **Files**: `modules/llm/default.nix`, `modules/llm/schema.ncl`, `inventory/services/services.ncl`, and focused module checks.
- **Risk**: Enabling the current inventory will start model pulls and an Ollama daemon that were previously absent.
- **Non-goals**: Do not merge the separate `modules/ollama` public schema without preserving compatibility.
- **Testing**: Evaluate the deployed `britton-desktop` role, assert Ollama service/model-pull wiring, verify firewall policy, preserve vLLM behavior, and reject unsupported types.
