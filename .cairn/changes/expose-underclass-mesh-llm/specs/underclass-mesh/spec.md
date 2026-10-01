## ADDED Requirements

### Requirement: Authenticated loopback gateway

r[onix.underclass.mesh.gateway] A machine that runs the local Underclass pool MAY serve it to Mesh-LLM only through a gateway bound to an IPv4 loopback address. The gateway MUST read the Underclass proxy key from a systemd credential, never from the Nix store, argv or logs. It MUST advertise only catalog entries owned by the Underclass Codex backend, translate chat completions into streamed Responses requests, and translate text, tool calls, usage and finish reasons back into chat-completion streams or objects. Fields with the same meaning in both APIs MUST reach Underclass unchanged. Only output-token caps, which the Codex subscription backend rejects, and Mesh-LLM's local chat-template reasoning switches MAY be dropped. Underclass errors MUST be relayed unchanged.

#### Scenario: Unauthenticated discovery

- GIVEN the gateway holds the current proxy key
- WHEN Mesh-LLM probes `GET /v1/models` without credentials
- THEN the Codex-backed Underclass models MUST be returned
- AND Copilot-backed entries MUST NOT be advertised
- AND a stale proxy key MUST surface Underclass's authentication failure

#### Scenario: Translated inference

- GIVEN an enrolled Codex account
- WHEN a client sends streaming, non-streaming or tool-calling chat completions
- THEN Underclass MUST receive a streamed Responses request carrying the translated conversation
- AND the client MUST receive the answer, indexed tool calls, usage and finish reason in chat-completions form

#### Scenario: Conversation affinity

- GIVEN a client that sends no `prompt_cache_key`, `promptCacheKey` or `session-id`
- WHEN it sends successive turns of one conversation
- THEN every turn MUST carry the same derived affinity key so Underclass keeps the conversation on one pooled account
- AND a client-supplied key MUST be forwarded unchanged

#### Scenario: Unsupported parameter

- GIVEN a request with a sampling control the Codex backend rejects
- WHEN it passes through the gateway
- THEN the backend's rejection MUST reach the client instead of the control being silently removed

### Requirement: Private mesh route

r[onix.underclass.mesh.route] Britton-desktop's Mesh-LLM sidecar MUST register the gateway as its named `underclass` endpoint while keeping its primary endpoint and research plugin. Every named `openai-endpoint` entry MUST identify itself with its configured plugin name so Mesh-LLM loads it. Remote mesh peers MUST discover the Underclass models and receive real answers through mesh transport.

#### Scenario: Remote peer uses the pool

- GIVEN the desktop sidecar, gateway and Underclass service are healthy
- WHEN Aspen2 lists models and sends chat-completions and Responses requests to its own loopback Mesh-LLM API
- THEN the Underclass Codex models MUST be listed
- AND streaming, non-streaming and tool-calling requests MUST return real answers from the desktop pool

### Requirement: Scoped exposure

r[onix.underclass.mesh.isolation] Only britton-desktop MAY run the gateway, and it MUST require the local Underclass pool on the same machine. The gateway and Underclass MUST keep loopback-only listeners with the firewall unchanged. The change MUST NOT move OAuth credentials, enable automatic banked-reset redemption, change mesh identity or join credentials, or restart the Underclass service.

#### Scenario: Unselected machines

- GIVEN any other mesh node
- WHEN its configuration is evaluated
- THEN it MUST NOT define the gateway or an `underclass` endpoint

### Requirement: Managed deployment

r[onix.underclass.mesh.deployment] Britton-desktop MUST run Underclass, the gateway, the mesh sidecar and its research ingress from its deployed NixOS generation, built from the lineage it already runs. No runtime unit, `/etc/systemd/system.control` override, manually installed secret or manually linked OMP extension MAY provide them, and the generation's closure difference MUST contain only this integration.

#### Scenario: Declarative ownership

- GIVEN the deployed generation
- WHEN systemd and Home Manager state are inspected
- THEN each unit MUST load from `/etc/systemd/system` and run the generation's store paths
- AND the secrets MUST come from the generation's sops activation
- AND the OMP provider link MUST belong to Home Manager

#### Scenario: Gateway without a local pool

- GIVEN `underclassMeshGateway` without `ompUnderclass`
- WHEN the configuration is evaluated
- THEN an assertion MUST reject it
