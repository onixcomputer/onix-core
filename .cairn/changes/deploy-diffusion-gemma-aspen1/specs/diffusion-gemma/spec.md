## Purpose

Serve the actual DiffusionGemma model on the available AMD Aspen host, preserving seeded-canvas structured reads and existing fleet isolation.

## ADDED Requirements

### Requirement: Verified native DiffusionGemma inference

r[onix.diffusion-gemma.runtime]
The deployment MUST use an immutable original DiffusionGemma model revision and an identified gfx1151-capable ROCm runtime. Completion MUST include successful real text generation and seeded-canvas read-only inference with returned label log probabilities, rather than a substitute autoregressive model, mock API or health-only check.

#### Scenario: Model answers through the deployed API

r[onix.diffusion-gemma.runtime.inference]
- **GIVEN** the pinned DiffusionGemma service on Aspen1
- **WHEN** a text request and a seeded-canvas structured request are submitted
- **THEN** the model produces real answers and the structured request returns the requested label log probabilities.

### Requirement: Isolated persistent model ownership

r[onix.diffusion-gemma.isolation]
The deployment MUST bind a separate loopback API, persist its service and model state, and prevent the existing stopped Aspen1 Qwen server from starting concurrently. It MUST preserve existing model files, Aspen2, Spark workloads, mesh routes and unrelated host services, without a whole-host activation.

#### Scenario: Restart retains the selected GPU owner

r[onix.diffusion-gemma.isolation.restart]
- **GIVEN** the deployed service and enabled persistent configuration
- **WHEN** the DiffusionGemma service is restarted
- **THEN** its API becomes healthy again, Qwen remains unable to claim the GPU, and unrelated services retain their prior state.
