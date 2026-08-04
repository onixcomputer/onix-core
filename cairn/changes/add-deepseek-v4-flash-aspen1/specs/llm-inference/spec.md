# LLM Inference Specification Delta

## REMOVED Requirements

### Requirement: Aspen1 Ornith BF16 trial
r[onix.aspen1.ornith.bf16] The `aspen1` Lemonade inventory MUST register and pull the official Ornith 1.0 35B BF16 GGUF while retaining the working 35B Q4_K_M model as a rollback target.

### Requirement: BF16 trial has positive and negative live validation
r[onix.aspen1.ornith.bf16.validation] The BF16 trial MUST verify useful generated output and service health, and MUST preserve the Q4 endpoint when BF16 download, load, inference, or resource checks fail.

Removal rationale: the 0731 server needs about 114 GiB resident on aspen1, so Lemonade and all aspen1 Ornith endpoints are removed from that host. The operator accepted this loss. aspen2 and aspen3 keep serving Ornith.

## ADDED Requirements

### Requirement: Aspen1 DeepSeek-V4-Flash-0731 runtime

r[onix.aspen1.deepseek.runtime] The system MUST provide a llama.cpp ROCm runtime pinned to the known-good commit `0b14b87d7c20cb753b94b96854dd7b45306fc696` for `gfx1151` with DSpark speculative decoding support, without changing the `llamacpp-rocm-rpc` runtime used by Lemonade hosts.

#### Scenario: Pinned dspark package builds

r[onix.aspen1.deepseek.runtime.package]
- GIVEN the custom `llamacpp-rocm-dspark` package is evaluated
- WHEN it builds
- THEN its source revision is `0b14b87d7c20cb753b94b96854dd7b45306fc696`
- AND it targets HIP `gfx1151`
- AND it provides `llama-server`
- AND `llamacpp-rocm-rpc` remains on its existing upstream tag

### Requirement: llamacpp-server shard and draft support

r[onix.aspen1.deepseek.module] The `llamacpp-server` module MUST pull multi-file GGUF models including subdirectory shard layouts and MUST support an optional draft model passed to `llama-server` with `--model-draft`.

#### Scenario: Sharded model with draft is pulled and launched

r[onix.aspen1.deepseek.module.shards]
- GIVEN a server instance with a shard subdirectory `modelFile`, two or more `extraModelFiles`, and a draft model
- WHEN the model pull service runs
- THEN every shard and the draft file are downloaded with parent directories created
- AND the server command includes `--model` for the first shard and `--model-draft` for the draft file

#### Scenario: Missing draft file blocks startup

r[onix.aspen1.deepseek.module.missing_draft]
- GIVEN a server instance configured with a draft model
- WHEN the draft file is absent from the state directory
- THEN the server service does not start
- AND the failed startup is visible in the unit status

### Requirement: Aspen1 serves DeepSeek-V4-Flash-0731 with DSpark

r[onix.aspen1.deepseek.serving] `aspen1` MUST serve `DeepSeek-V4-Flash-0731` as UD-IQ3_XXS with the MXFP4-Q8_0 DSpark drafter through `llamacpp-server` on port 13305, and the aspen1 mesh-llm seed MUST route to that service.

#### Scenario: Inventory wires the verified configuration

r[onix.aspen1.deepseek.serving.inventory]
- GIVEN the evaluated `aspen1` NixOS configuration
- WHEN the `llamacpp-server-deepseek-v4-flash-aspen1` unit and mesh-llm seed settings are inspected
- THEN the model is the unsloth `UD-IQ3_XXS` first shard with three extra shards
- AND the draft model is `DeepSeek-V4-Flash-0731-DSpark-Drafter-MXFP4-Q8_0.gguf`
- AND the server arguments include `--spec-type draft-dspark` and `--spec-draft-n-max 3`
- AND the port is 13305
- AND the aspen1 mesh-llm `backendUnit` is `llamacpp-server-deepseek-v4-flash-aspen1.service`

### Requirement: Aspen1 inference memory exclusivity

r[onix.aspen1.deepseek.exclusivity] `aspen1` MUST NOT run Lemonade alongside the 0731 server, because the verified deployment needs about 120 GiB free at startup and about 114 GiB resident.

#### Scenario: Lemonade is absent from aspen1

r[onix.aspen1.deepseek.exclusivity.no_lemonade]
- GIVEN the evaluated `aspen1` NixOS configuration
- WHEN its systemd services are inspected
- THEN no `lemonade.service` unit is present
- AND kokoro-v1 and aspen1 Ornith endpoints are no longer served on aspen1

### Requirement: DeepSeek live validation

r[onix.aspen1.deepseek.validation] The change MUST include positive and negative live validation of the deployed 0731 server on aspen1.

#### Scenario: Chat probe succeeds with speculative decode

r[onix.aspen1.deepseek.validation.positive]
- GIVEN the deployed server answered a health check
- WHEN a live chat completion asks `What is 2+2?`
- THEN the response content contains `4`
- AND the server reports DSpark speculative decoding activity

#### Scenario: Load without generation is not accepted

r[onix.aspen1.deepseek.validation.negative]
- GIVEN a deployment where the model loads but generation fails, loops, or the unit restarts
- WHEN the probe result is evaluated
- THEN the deployment is recorded as failed
- AND successful weight load alone is not accepted as health evidence
