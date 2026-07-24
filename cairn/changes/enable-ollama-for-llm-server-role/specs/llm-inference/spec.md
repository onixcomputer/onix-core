# LLM Inference Specification Delta

## Purpose

Make the generic LLM server role instantiate its selected backend or fail closed when the backend is unsupported.

## ADDED Requirements

### Requirement: Ollama service type starts a managed server

r[onix.llm.service.ollama] The LLM server role with `serviceType = "ollama"` MUST enable a managed Ollama service using the configured host, port, GPU policy, package policy, and model list.

#### Scenario: Deployed desktop Ollama role evaluates

r[onix.llm.service.ollama.desktop]
- GIVEN the `britton-desktop` inventory selects the LLM server role with Ollama and model `qwen3.5:9b`
- WHEN its NixOS configuration is evaluated
- THEN the Ollama service is enabled on the configured host and port
- AND a managed model-pull unit includes the configured model

#### Scenario: Ollama model list is empty

r[onix.llm.service.ollama.empty_models]
- GIVEN Ollama is selected with no models
- WHEN the role evaluates
- THEN the Ollama service remains enabled
- AND no model-pull unit performs an empty pull loop

### Requirement: Backend selection is total

r[onix.llm.service.total] Every `serviceType` accepted by the LLM server schema MUST either render a managed backend or fail evaluation with a clear unsupported-backend diagnostic.

#### Scenario: Supported vLLM remains managed

r[onix.llm.service.total.vllm]
- GIVEN vLLM is selected with a valid primary model
- WHEN the role evaluates
- THEN the managed vLLM service is rendered
- AND Ollama service wiring is absent

#### Scenario: Declared but unimplemented backend is selected

r[onix.llm.service.total.unsupported]
- GIVEN a schema value has no implemented server backend
- WHEN the role evaluates
- THEN evaluation MUST fail with an unsupported-backend diagnostic
- AND it MUST NOT merely install client packages or open a firewall port

### Requirement: LLM firewall follows effective binding

r[onix.llm.service.network] The LLM server role MUST open its firewall port only when the selected backend is enabled and its effective bind address is non-loopback.

#### Scenario: Loopback Ollama remains local

r[onix.llm.service.network.loopback]
- GIVEN Ollama is configured to bind a loopback address
- WHEN the role evaluates
- THEN the service uses that loopback address
- AND the port is absent from global firewall allowances

#### Scenario: Remote Ollama bind opens configured port

r[onix.llm.service.network.remote]
- GIVEN Ollama is configured to bind a non-loopback address
- WHEN the role evaluates
- THEN the configured port is allowed by the intended firewall policy
- AND the running service uses the same host and port

### Requirement: LLM backend selection has positive and negative validation

r[onix.llm.service.validation] The repository MUST include focused checks for Ollama, vLLM, local-only binding, deployed inventory, and unsupported backend selection.

#### Scenario: Focused module checks pass

r[onix.llm.service.validation.focused]
- GIVEN the generic LLM module and current service inventory
- WHEN focused Nix evaluation checks run
- THEN supported backends render their expected services
- AND unsupported or inconsistent configurations fail with expected diagnostics
