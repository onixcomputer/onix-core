# LLM Inference Specification

## Purpose

Define local LLM serving behavior for Onix-managed inference hosts.

## Requirements

### Requirement: Aspen3 Ornith runtime

r[onix.aspen3.ornith.runtime] The system MUST provide a recent llama.cpp ROCm/RPC runtime for `aspen3` Ornith serving while preserving the managed RPC worker command surface.

#### Scenario: Recent llama.cpp package builds

r[onix.aspen3.ornith.runtime.package]
- GIVEN the custom `llamacpp-rocm-rpc` package is evaluated
- WHEN it builds
- THEN the package uses a recent upstream llama.cpp tag
- AND it provides `llama-server` for Lemonade
- AND it provides a `llama-rpc-server` compatibility command for managed RPC workers

### Requirement: Aspen3 Ornith model selection

r[onix.aspen3.ornith.model] `aspen3` MUST serve a live-validated 35B Ornith model and MUST NOT advertise the broken Q8 35B endpoint as the configured 35B choice.

#### Scenario: Q4 35B is the served Ornith 35B model

r[onix.aspen3.ornith.model.q4]
- GIVEN the `aspen3` Lemonade service inventory is evaluated
- WHEN its configured model list is inspected
- THEN `user.Ornith-1.0-35B-Q4_K_M` is included
- AND `user.Ornith-1.0-9B-Q8_0` remains included as a fast fallback
- AND `user.Ornith-1.0-35B-Q8_0` is not included in the served model list

#### Scenario: Q8 35B slash-loop is rejected

r[onix.aspen3.ornith.model.q8_rejected]
- GIVEN live inference diagnostics for `user.Ornith-1.0-35B-Q8_0`
- WHEN chat and completion probes return repeated `/` tokens instead of useful text
- THEN that model is treated as unhealthy for `aspen3`
- AND the system selects the validated Q4_K_M quantization instead

### Requirement: Aspen3 Ornith verification

r[onix.aspen3.ornith.verification] The change MUST include focused positive and negative validation evidence for the `aspen3` Ornith repair.

#### Scenario: Q4 live response succeeds

r[onix.aspen3.ornith.verification.positive]
- GIVEN `user.Ornith-1.0-35B-Q4_K_M` is pulled and served on `aspen3`
- WHEN a live chat completion asks `What is 2+2?`
- THEN the response content is `4`
- AND the request finishes successfully

#### Scenario: Q8 diagnostic prevents false success

r[onix.aspen3.ornith.verification.negative]
- GIVEN `user.Ornith-1.0-35B-Q8_0` loads without transport errors
- WHEN a focused diagnostic inspects its generated output
- THEN repeated slash tokens are recorded as a failure mode
- AND successful model load alone is not accepted as health evidence

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

r[onix.aspen1.deepseek.serving] `aspen1` MUST serve `DeepSeek-V4-Flash-0731` as UD-IQ3_XXS with a `dflash`-architecture DSpark drafter through `llamacpp-server` on port 13305, and the aspen1 mesh-llm seed MUST route to that service.

#### Scenario: Inventory wires the verified configuration

r[onix.aspen1.deepseek.serving.inventory]
- GIVEN the evaluated `aspen1` NixOS configuration
- WHEN the `llamacpp-server-deepseek-v4-flash-aspen1` unit and mesh-llm seed settings are inspected
- THEN the model is the unsloth `UD-IQ3_XXS` first shard with three extra shards
- AND the draft model is `DeepSeek-V4-Flash-0731-DSpark-llamacpp-MXFP4-Q8_0.gguf` converted from the official checkpoint
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
