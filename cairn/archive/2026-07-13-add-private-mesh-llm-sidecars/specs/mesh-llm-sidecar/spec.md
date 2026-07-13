# Mesh-LLM Sidecar Specification Delta

## Purpose

Expose Aspen1 and `britton-desktop` inference through a private, Nix-managed two-node Mesh-LLM routing layer without changing existing inference runtimes or other Aspen hosts.

## ADDED Requirements

### Requirement: Existing local inference endpoints are advertised through sidecars

r[onix.mesh_llm.sidecar] Each selected node MUST run a Nix-managed Mesh-LLM sidecar whose openai-endpoint plugin targets `http://127.0.0.1:13305/v1`.

#### Scenario: Aspen1 advertises Lemonade models

r[onix.mesh_llm.sidecar.aspen1]
- GIVEN Aspen1's Lemonade endpoint is healthy
- WHEN the Aspen1 Mesh-LLM API is queried
- THEN its model list includes models returned by the local Lemonade endpoint
- AND inference continues through the existing Aspen1-to-Aspen2 llama.cpp RPC topology

#### Scenario: Desktop advertises VibeThinker

r[onix.mesh_llm.sidecar.desktop]
- GIVEN `britton-desktop`'s llama.cpp endpoint is healthy
- WHEN the desktop Mesh-LLM API is queried
- THEN its model list includes `VibeThinker-3B`
- AND the authoritative VibeThinker runtime remains the existing local llama.cpp service
- AND any Mesh-LLM compatibility model is CPU-only with a bounded context

### Requirement: The two sidecars form a private LAN-only mesh

r[onix.mesh_llm.private] Aspen1 and `britton-desktop` MUST share one invite-token-based mesh without public publication, Nostr discovery, public relay registration, or raw public STUN startup.

#### Scenario: Seed and joiner share identity

r[onix.mesh_llm.private.membership]
- GIVEN Aspen1 is running as the originator and the desktop has its current invite credential
- WHEN both sidecars are healthy
- THEN both status payloads report the same non-empty mesh ID
- AND each reports the other node as a peer

#### Scenario: Public discovery remains disabled

r[onix.mesh_llm.private.discovery]
- GIVEN either managed sidecar starts
- WHEN its launch arguments and status are inspected
- THEN discovery mode is `mdns`
- AND publication state is private
- AND no `--publish`, `--auto`, or `--listen-all` flag is present
- AND GPU devices remain inaccessible to the sidecar

### Requirement: Secrets and listeners fail closed

r[onix.mesh_llm.security] The join token MUST stay out of the Nix store and HTTP listeners MUST remain loopback-only.

#### Scenario: Join credential is supplied at runtime

r[onix.mesh_llm.security.credential]
- GIVEN the desktop sidecar starts
- WHEN systemd resolves its credentials
- THEN the join token comes from a Clan-managed secret through `LoadCredential`
- AND the token is absent from generated Nix configuration text

#### Scenario: Join credential is invalid

r[onix.mesh_llm.security.invalid_credential]
- GIVEN the desktop credential is missing, empty, or the stock SOPS placeholder
- WHEN its service wrapper starts
- THEN startup fails with a clear credential diagnostic
- AND the node MUST NOT silently create a second private mesh

#### Scenario: HTTP exposure is local only

r[onix.mesh_llm.security.loopback]
- GIVEN a managed sidecar is running
- WHEN listening sockets are inspected
- THEN API port 9337 and management port 3131 bind only to loopback
- AND only the configured mesh UDP port is opened by the host firewall

### Requirement: Unselected Aspen hosts remain untouched

r[onix.mesh_llm.scope] The Mesh-LLM service MUST be assigned only to Aspen1 and `britton-desktop`.

#### Scenario: Aspen2 and Aspen3 evaluate without sidecars

r[onix.mesh_llm.scope.excluded]
- GIVEN Aspen2 and Aspen3 machine configurations are evaluated
- WHEN systemd units and firewall rules are inspected
- THEN neither machine contains the managed Mesh-LLM sidecar unit
- AND no Mesh-LLM mesh port is added for those machines

### Requirement: Package and module behavior are validated

r[onix.mesh_llm.validation] The repository MUST include positive and negative checks for the packaged executable, seed/joiner wiring, private listener policy, credential policy, and assignment scope.

#### Scenario: Focused validation passes

r[onix.mesh_llm.validation.focused]
- GIVEN the current package, module, and service inventory
- WHEN focused Nix and Nickel checks run
- THEN the package exposes both required executables
- AND Aspen1 and desktop render their expected modes and bounded plugin-proxy activation arguments
- AND invalid or excluded configurations fail or remain absent as specified
