# Llamacpp Metalium Serving Specification

## Purpose

Defines the reusable `llamacpp-metalium-serving` capability.

## Requirements

### Requirement: Metalium is a selectable llama.cpp backend

r[onix.llamacpp_server.metalium_backend] The schema-driven `llamacpp-server` service MUST select the pinned `llama-cpp-metalium` package when configured with the Metalium backend and MUST expose an explicit non-negative device identifier.

#### Scenario: Metalium backend selects a physical device

- GIVEN a valid `llamacpp-server` instance configured with the Metalium backend
- WHEN NixOS evaluates the generated systemd service
- THEN the service command uses the pinned Metalium `llama-server`
- AND the service environment selects the configured physical device identifier

### Requirement: Metalium serving rejects unsupported runtime combinations

r[onix.llamacpp_server.metalium_safety] A Metalium `llamacpp-server` instance MUST keep KV cache on the CPU, MUST reject flash attention and explicit quantized KV-cache types, and MUST remove mesh variables from its service environment.

#### Scenario: Safe default Metalium configuration evaluates

- GIVEN a Metalium instance with flash attention disabled and no KV-cache override
- WHEN the module assertions are evaluated
- THEN the configuration succeeds
- AND the generated command contains `--no-kv-offload`

#### Scenario: Unsupported Metalium cache configuration is rejected

- GIVEN a Metalium instance with flash attention or an explicit KV-cache type
- WHEN the module assertions are evaluated
- THEN evaluation reports a configuration error

### Requirement: The former desktop VibeThinker deployment is retired

r[onix.tenstorrent.p150x2_qwen.exclusivity] The reusable llama.cpp module MUST remain available, but `britton-desktop` MUST NOT assign the former VibeThinker instance while Qwen owns both P150 devices.

#### Scenario: Desktop service inventory is evaluated

- GIVEN the `britton-desktop` service inventory
- WHEN assigned llama.cpp instances are inspected
- THEN no `vibethinker-britton-desktop` instance is assigned
- AND the generic Metalium module checks remain available for future reviewed instances
