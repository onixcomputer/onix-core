## Purpose

Expose the already-deployed Aspen1 DiffusionGemma model through the existing private Mesh-LLM network.

## ADDED Requirements

### Requirement: Reachable DiffusionGemma mesh provider

r[onix.diffusion-gemma.mesh]
The Aspen1 mesh provider MUST discover the deployed diffusiongemma model through its loopback OpenAI endpoint and depend on its actual DiffusionGemma systemd unit. An existing remote mesh peer MUST list the model and successfully serve real non-streaming and streaming requests for it. The mesh MUST retain client request semantics rather than silently changing unsupported sampling controls.

#### Scenario: Existing peer uses the new model

r[onix.diffusion-gemma.mesh.inference]
- **GIVEN** the existing private mesh and healthy DiffusionGemma backend
- **WHEN** a desktop client lists models and requests a diffusiongemma completion without unsupported sampling controls
- **THEN** the model is discoverable and its real answer is returned through mesh transport, including a completed streaming response.

### Requirement: Scoped persistent route replacement

r[onix.diffusion-gemma.mesh-isolation]
The change MUST replace Aspen1's old Qwen route and dependency without changing other providers, mesh identity, join credentials or private listener boundaries. Activation MUST persist across service restarts, keep Qwen masked, and leave the model backend, structured frontend and unrelated services running without restart. It MUST NOT perform a whole-host activation.

#### Scenario: Sidecar restart preserves inference ownership

r[onix.diffusion-gemma.mesh-isolation.restart]
- **GIVEN** the generated Aspen1 mesh unit and retained persistent mesh state
- **WHEN** only the mesh sidecar is restarted with the new endpoint
- **THEN** existing peers reconnect, DiffusionGemma remains the active GPU owner, and the protected services retain their invocation identities.
