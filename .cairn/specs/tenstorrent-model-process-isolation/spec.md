# Tenstorrent Model Process Isolation Specification

## Purpose

Defines the `tenstorrent-model-process-isolation` capability.

## Requirements

### Requirement: Metalium model processes isolate physical devices

r[onix.tenstorrent.model_process_isolation.devices] Each independent Metalium model service MUST restrict UMD discovery to its configured physical PCIe device through `TT_VISIBLE_DEVICES`, MUST select logical device 0 after filtering, and MUST remove mesh-shape and mesh-descriptor variables from the service environment.

#### Scenario: Physical card 1 is remapped for an isolated process

- GIVEN a Metalium service configured for physical device 1
- WHEN the service environment is generated
- THEN `TT_VISIBLE_DEVICES` equals `1`
- AND `GGML_METALIUM_DEVICE_ID` equals `0`
- AND the service does not inherit a multi-card mesh shape or descriptor

#### Scenario: Invalid physical device identifiers are rejected

- GIVEN a Metalium service with a negative or non-integer physical device identifier
- WHEN module assertions are evaluated
- THEN evaluation reports a configuration error

### Requirement: Metalium model processes isolate mutable runtime state

r[onix.tenstorrent.model_process_isolation.state] Each independent Metalium model service MUST use a service-private `TT_METAL_CACHE`, MUST write generated TT-Metal logs outside the source repository, and MUST use an inspector RPC address that does not collide with another deployed Metalium service.

#### Scenario: Two model services start without cache or device-lock contention

- GIVEN VibeThinker and Supra-Router-51M are assigned different physical cards and state paths
- WHEN both services start concurrently
- THEN neither process waits for the other process's `CHIP_IN_USE` lock
- AND neither process shares a kernel compilation cache

### Requirement: Supra-Router-51M preserves P150 capacity

r[onix.tenstorrent.concurrent_models.supra] The `llamacpp-server-supra-router` service MUST preserve port 13306, its model alias, deterministic sampling, routing output behavior, and GGUF model path, MUST use the CPU backend when its checked throughput equals or exceeds the former tuned Metalium deployment, and MUST NOT claim or reserve a Tenstorrent physical device needed by a supported larger model service.

#### Scenario: Supra returns a routing decision while both P150s serve larger models

- GIVEN VibeThinker owns physical card 0 and Llama-3.1-8B-Instruct owns physical card 1
- WHEN a structurally framed routing prompt is submitted to CPU Supra on port 13306 while VibeThinker handles a request
- THEN Supra returns the expected pipe-separated routing schema and fixed-input output
- AND Supra throughput does not materially regress from its former tuned Metalium deployment
- AND Supra does not acquire a Tenstorrent device lock, cache, or Inspector endpoint

### Requirement: VibeThinker remains on physical card 0

r[onix.tenstorrent.concurrent_models.vibethinker] The `britton-desktop` VibeThinker service MUST remain assigned to physical card 0 while the host-level P150x2 descriptor remains available for explicitly mesh-aware TT-Metal and TT-NN workloads.

#### Scenario: Host topology and process isolation coexist

- GIVEN the Tenstorrent host tag exports the P150x2 descriptor
- WHEN the two single-card model units are generated
- THEN the host environment retains the descriptor
- AND each model service removes the descriptor from its own process environment
