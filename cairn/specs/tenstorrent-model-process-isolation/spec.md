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

### Requirement: Supra-Router-51M runs on physical card 1

r[onix.tenstorrent.concurrent_models.supra] The `llamacpp-server-supra-router` service MUST use the pinned Metalium package on physical card 1, MUST keep KV cache on the CPU, MUST disable flash attention and mesh aggregation, and MUST preserve its port 13306, model alias, deterministic sampling, and GGUF model path.

#### Scenario: Supra returns a routing decision while VibeThinker is active

- GIVEN both model services are healthy
- WHEN a structurally framed routing prompt is submitted to Supra on port 13306 while VibeThinker handles a request on port 13305
- THEN Supra returns the expected pipe-separated routing schema
- AND both requests complete successfully

### Requirement: VibeThinker remains on physical card 0

r[onix.tenstorrent.concurrent_models.vibethinker] The `britton-desktop` VibeThinker service MUST remain assigned to physical card 0 while the host-level P150x2 descriptor remains available for explicitly mesh-aware TT-Metal and TT-NN workloads.

#### Scenario: Host topology and process isolation coexist

- GIVEN the Tenstorrent host tag exports the P150x2 descriptor
- WHEN the two single-card model units are generated
- THEN the host environment retains the descriptor
- AND each model service removes the descriptor from its own process environment
