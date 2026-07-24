## Context

The generic `llm` role advertises several `serviceType` values. Its implementation creates only a vLLM container. In Ollama mode it installs `pkgs.ollama`, but does not enable `services.ollama` or the model-pull unit provided by the separate Ollama module. The active desktop inventory selects this inert path.

## Decisions

### 1. Make backend selection total and explicit

**Choice:** Every accepted `serviceType` must either produce a managed server configuration or fail evaluation with an unsupported-backend diagnostic. Ollama and vLLM are the initially supported server backends.

**Rationale:** Silent no-op service modes violate the role contract and are hard to diagnose.

### 2. Reuse Ollama behavior without duplicating policy

**Choice:** Extract or share a pure settings-to-Nix configuration helper with `modules/ollama`, preserving that module's host, port, model-pull, package, and environment semantics.

**Rationale:** Two independent Ollama implementations would drift. The helper is the testable core; each Clan role remains a thin module shell.

### 3. Honor host and firewall settings

**Choice:** Pass the configured host and port to the selected backend. Open the firewall only for non-loopback binds, using the repository's existing local-only host classification.

**Rationale:** The current module ignores `host` for vLLM and opens a port even when no server exists.

### 4. Validate the deployed inventory path

**Choice:** Add focused module checks that evaluate the actual `llm` inventory on `britton-desktop`, including the model list and service dependencies.

**Rationale:** Generic fixtures alone can miss a mismatch between service schema and deployed settings.

## Risks / Trade-offs

- Starting Ollama may trigger large model downloads and resource use on the next deployment.
- Shared helper extraction must preserve the standalone Ollama service interface.
- Unsupported declared enum values may become evaluation errors until their backends are implemented.
