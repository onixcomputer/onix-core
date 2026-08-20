# Tenstorrent Model Process Isolation Specification

## Purpose

Defines the `tenstorrent-model-process-isolation` capability.

## Requirements

### Requirement: Independent Metalium processes isolate devices

r[onix.tenstorrent.model_process_isolation.devices] An independent single-device Metalium process MUST restrict UMD discovery through `TT_VISIBLE_DEVICES`, MUST select logical device 0 after filtering, and MUST remove mesh variables from its process environment.

#### Scenario: A physical card is remapped for a diagnostic process

- GIVEN a diagnostic selects one physical P150
- WHEN its isolated process environment is generated
- THEN only that physical device is visible
- AND the process selects logical device 0
- AND the process does not inherit the host P150x2 descriptor

#### Scenario: An invalid physical device identifier is rejected

- GIVEN a negative or non-integer physical device identifier
- WHEN module assertions are evaluated
- THEN evaluation reports a configuration error

### Requirement: Model processes isolate mutable runtime state

r[onix.tenstorrent.model_process_isolation.state] Each Metalium process MUST use private cache and log paths, and each Inspector endpoint MUST not collide with another process.

#### Scenario: A diagnostic runs beside CPU Supra

- GIVEN CPU Supra is active and Qwen is isolated before the diagnostic starts
- WHEN the diagnostic creates its runtime paths
- THEN it does not share Qwen cache or log state
- AND it does not claim Supra resources

### Requirement: Supra-Router-51M preserves P150 capacity

r[onix.tenstorrent.concurrent_models.supra] The `llamacpp-server-supra-router` service MUST preserve port 13306, its model alias, deterministic sampling, routing output, and GGUF model path, and MUST NOT reserve a Tenstorrent device.

#### Scenario: Supra returns a routing decision while Qwen owns both P150s

- GIVEN Qwen owns physical devices 0 and 1
- WHEN a routing prompt is submitted to CPU Supra on port 13306
- THEN Supra returns its expected routing schema
- AND Supra does not acquire a Tenstorrent device lock, cache, or Inspector endpoint

### Requirement: Qwen has exclusive P150x2 ownership

r[onix.tenstorrent.p150x2_qwen.exclusivity] `qwen38-p150x2.service` MUST be the only automatically started model service that can acquire either P150 device.

#### Scenario: Host topology and Qwen ownership coexist

- GIVEN the Tenstorrent host tag exports the P150x2 descriptor
- WHEN the Qwen service starts
- THEN it requires both device nodes
- AND it clears ambient mesh and simulator variables
- AND the former single-card VibeThinker and Llama services remain absent
