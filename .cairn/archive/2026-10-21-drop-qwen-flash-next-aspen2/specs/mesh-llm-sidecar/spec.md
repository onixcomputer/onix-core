# Mesh LLM Sidecar Specification Delta

## MODIFIED Requirements

### Requirement: Local inference endpoints are advertised through sidecars

r[onix.mesh_llm.sidecar] Each selected node MUST run a Nix-managed Mesh-LLM sidecar. A node with a local inference backend MUST point its OpenAI endpoint plugin at that node's declared loopback `/v1` endpoint. A node without one MUST NOT render an OpenAI endpoint plugin or declare a backend unit.

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

#### Scenario: Aspen2 provides research without local inference

r[onix.mesh_llm.sidecar.research_only]
- GIVEN the evaluated `aspen2` NixOS configuration
- WHEN its Mesh-LLM sidecar configuration is rendered
- THEN it contains the research plugin for the arXiv corpus and Laya
- AND it contains no OpenAI endpoint plugin
- AND no `llamacpp-server-qwen38-flash-next-aspen2` unit or token generator exists

### Requirement: Package and module behavior are validated

r[onix.mesh_llm.validation] The repository MUST include positive and negative checks for executable packaging, endpoint wiring, private listeners, credentials, and assignment scope.

#### Scenario: Focused validation passes

- GIVEN the current package, module, and service inventory
- WHEN focused Nix and Nickel checks run
- THEN required executables exist
- AND each node with a local backend renders its declared endpoint and backend ordering
- AND a node without a local endpoint renders no OpenAI endpoint plugin
- AND invalid credentials, missing private bindings, or a backend without an endpoint fail
