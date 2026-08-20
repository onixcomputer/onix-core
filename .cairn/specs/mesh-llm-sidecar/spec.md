# Mesh Llm Sidecar Specification

## Purpose

Defines the `mesh-llm-sidecar` capability.

## Requirements

### Requirement: Local inference endpoints are advertised through sidecars

r[onix.mesh_llm.sidecar] Each selected node MUST run a Nix-managed Mesh-LLM sidecar whose OpenAI endpoint plugin targets that node's declared loopback `/v1` endpoint.

#### Scenario: Aspen nodes advertise their local endpoints

- GIVEN an Aspen node's local endpoint is healthy
- WHEN its Mesh-LLM API is queried
- THEN its model list includes models returned by that local endpoint
- AND its configured backend unit starts before the sidecar

#### Scenario: Desktop advertises Qwen3.8-27B

r[onix.mesh_llm.sidecar.desktop]
- GIVEN `qwen38-p150x2.service` is healthy on `127.0.0.1:8000`
- WHEN the desktop Mesh-LLM API is queried
- THEN its model list includes `Qwen3.8-27B`
- AND the sidecar targets `http://127.0.0.1:8000/v1`
- AND `qwen38-p150x2.service` starts before the sidecar

### Requirement: The sidecars form a private LAN-only mesh

r[onix.mesh_llm.private] Selected nodes MUST share one invite-token-based mesh without public publication, Nostr discovery, public relay registration, or raw public STUN startup.

#### Scenario: Seed and joiners share identity

- GIVEN the seed is running and each joiner has its current invite credential
- WHEN the sidecars are healthy
- THEN status payloads report the same non-empty mesh ID
- AND each reports the expected peers

#### Scenario: Public discovery remains disabled

- GIVEN any managed sidecar starts
- WHEN its launch arguments and status are inspected
- THEN discovery mode is `mdns`
- AND publication state is private
- AND no `--publish`, `--auto`, or `--listen-all` flag is present
- AND accelerator devices remain inaccessible to the sidecar

### Requirement: Secrets and listeners fail closed

r[onix.mesh_llm.security] Join tokens MUST stay out of the Nix store and HTTP listeners MUST remain loopback-only.

#### Scenario: Join credential is supplied at runtime

- GIVEN a joiner starts
- WHEN systemd resolves its credentials
- THEN the join token comes from a Clan-managed secret through `LoadCredential`
- AND the token is absent from generated Nix configuration text

#### Scenario: Join credential is invalid

- GIVEN a join credential is missing, empty, or the stock SOPS placeholder
- WHEN its service wrapper starts
- THEN startup fails with a clear diagnostic
- AND the node does not create a second private mesh

#### Scenario: HTTP exposure is local only

- GIVEN a managed sidecar is running
- WHEN listening sockets are inspected
- THEN API port 9337 and management port 3131 bind only to loopback
- AND only the configured mesh UDP port is opened by the host firewall

### Requirement: Assignment scope remains explicit

r[onix.mesh_llm.scope] Each Mesh-LLM instance MUST be assigned only through reviewed machine or tag roles.

#### Scenario: An unselected host is evaluated

- GIVEN a machine without a Mesh-LLM role
- WHEN its systemd units and firewall rules are inspected
- THEN no managed Mesh-LLM sidecar exists
- AND no Mesh-LLM mesh port is opened

### Requirement: Package and module behavior are validated

r[onix.mesh_llm.validation] The repository MUST include positive and negative checks for executable packaging, endpoint wiring, private listeners, credentials, and assignment scope.

#### Scenario: Focused validation passes

- GIVEN the current package, module, and service inventory
- WHEN focused Nix and Nickel checks run
- THEN required executables exist
- AND each node renders its declared endpoint and backend ordering
- AND invalid credentials or missing private bindings fail
