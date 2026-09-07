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

### Requirement: Aspen1 Qwen3.8 Flash Next runtime

r[onix.aspen1.qwen_flash.runtime] The system MUST provide a separate llama.cpp ROCm runtime pinned to upstream commit `427291b5b34cd914a31b3fd3b61a68f6184f4b9f` for Qwen4Exp on HIP `gfx1151`, without changing the DeepSeek or Lemonade runtime packages.

#### Scenario: Pinned Qwen4Exp package builds

r[onix.aspen1.qwen_flash.runtime.package]
- GIVEN the custom `llamacpp-rocm-qwen4exp` package is evaluated
- WHEN it builds
- THEN its source revision is `427291b5b34cd914a31b3fd3b61a68f6184f4b9f`
- AND it targets HIP `gfx1151`
- AND it provides `llama-server`
- AND the existing DeepSeek and Lemonade package pins remain unchanged

### Requirement: Gated multimodal GGUF downloads remain private

r[onix.aspen1.qwen_flash.download] The `llamacpp-server` module MUST support revision-pinned, hash-checked GGUF shards and a multimodal projector from a gated Hugging Face repository. It MUST keep the access token out of the Nix store, command line, and logs.

#### Scenario: Authorized model files are downloaded

r[onix.aspen1.qwen_flash.download.authorized]
- GIVEN a valid deployed Hugging Face token and matching artifact hashes
- WHEN the model pull service runs
- THEN it authenticates through a temporary root-only header file
- AND it downloads every model shard and the multimodal projector
- AND it rejects any file whose SHA-256 value does not match

#### Scenario: Missing authorization fails closed

r[onix.aspen1.qwen_flash.download.denied]
- GIVEN the token is absent, malformed, or unauthorized for the gated repository
- WHEN the model pull service starts
- THEN it exits before any model download
- AND the inference service does not start

### Requirement: Aspen1 serves uncensored Qwen3.8 Flash Next

r[onix.aspen1.qwen_flash.serving] `aspen1` MUST serve the OrcaRouter Qwen3.8 Flash Next Uncensored IQ4_XS GGUF with its multimodal projector through `llamacpp-server` on loopback port 13305. The aspen1 mesh-llm seed MUST route to that service.

#### Scenario: Inventory wires the Qwen service

r[onix.aspen1.qwen_flash.serving.inventory]
- GIVEN the evaluated `aspen1` NixOS configuration
- WHEN the `llamacpp-server-qwen38-flash-next-aspen1` unit and mesh-llm seed settings are inspected
- THEN the model revision is `d2e41a316ee631cf17f83c8827800c836d30cbe6`
- AND the model is the three-shard IQ4_XS quantization
- AND the F16 multimodal projector is present
- AND the direct server binds only to `127.0.0.1:13305`
- AND the aspen1 mesh-llm `backendUnit` is `llamacpp-server-qwen38-flash-next-aspen1.service`

### Requirement: Aspen1 Qwen inference memory exclusivity

r[onix.aspen1.qwen_flash.exclusivity] `aspen1` MUST NOT run DeepSeek or Lemonade alongside Qwen3.8 Flash Next because these model services compete for the same unified-memory capacity.

#### Scenario: Competing inference services are absent

r[onix.aspen1.qwen_flash.exclusivity.no_competitors]
- GIVEN the evaluated `aspen1` NixOS configuration
- WHEN its systemd services are inspected
- THEN no DeepSeek llama.cpp service is configured
- AND no `lemonade.service` unit is configured

### Requirement: Qwen3.8 Flash Next live validation

r[onix.aspen1.qwen_flash.validation] The deployment MUST include positive and negative live validation of the Qwen3.8 Flash Next service on aspen1.

#### Scenario: Text and vision probes succeed

r[onix.aspen1.qwen_flash.validation.positive]
- GIVEN the deployed server answered a health probe
- WHEN bounded text and image chat completions run
- THEN both responses contain useful content
- AND the model identity is `Qwen3.8-Flash-Next-Uncensored`
- AND runtime metrics report successful prompt and decode work

#### Scenario: Load without useful generation is rejected

r[onix.aspen1.qwen_flash.validation.negative]
- GIVEN a deployment where the model loads but generation fails, loops, or restarts the unit
- WHEN the probe result is evaluated
- THEN the deployment is recorded as failed
- AND successful weight load alone is not accepted as health evidence

### Requirement: Aspen2 serves uncensored Qwen3.8 Flash Next

r[onix.aspen2.qwen_flash.serving] `aspen2` MUST serve the same revision-pinned OrcaRouter Qwen3.8 Flash Next Uncensored IQ4_XS GGUF and multimodal projector as `aspen1`. The direct server MUST bind to loopback port 13305. The `aspen2` mesh-llm joiner MUST route to that service.

#### Scenario: Inventory wires the Aspen2 Qwen service

r[onix.aspen2.qwen_flash.serving.inventory]
- GIVEN the evaluated `aspen2` NixOS configuration
- WHEN the `llamacpp-server-qwen38-flash-next-aspen2` unit and mesh-llm joiner settings are inspected
- THEN the model revision is `d2e41a316ee631cf17f83c8827800c836d30cbe6`
- AND the model is the three-shard IQ4_XS quantization
- AND the F16 multimodal projector is present
- AND the direct server binds only to `127.0.0.1:13305`
- AND the mesh-llm `backendUnit` is `llamacpp-server-qwen38-flash-next-aspen2.service`

### Requirement: Aspen2 Qwen inference memory exclusivity

r[onix.aspen2.qwen_flash.exclusivity] `aspen2` MUST NOT run Lemonade alongside Qwen3.8 Flash Next because both model services compete for the same unified-memory capacity.

#### Scenario: Lemonade is absent

r[onix.aspen2.qwen_flash.exclusivity.no_competitors]
- GIVEN the evaluated `aspen2` NixOS configuration
- WHEN its systemd services are inspected
- THEN the Qwen llama.cpp service is configured
- AND no `lemonade.service` unit is configured

### Requirement: Aspen2 Qwen3.8 Flash Next live validation

r[onix.aspen2.qwen_flash.validation] The deployment MUST include positive and negative live validation of the Qwen3.8 Flash Next service on `aspen2`.

#### Scenario: Text and vision probes succeed

r[onix.aspen2.qwen_flash.validation.positive]
- GIVEN the deployed server answered a health probe
- WHEN bounded text and image chat completions run
- THEN both responses contain useful content
- AND the model identity is `Qwen3.8-Flash-Next-Uncensored`
- AND runtime metrics report successful prompt and decode work

#### Scenario: Private and fail-closed behavior is verified

r[onix.aspen2.qwen_flash.validation.negative]
- GIVEN the Qwen service is deployed on `aspen2`
- WHEN direct Tailnet access, malformed authorization, competing services, and service restarts are inspected
- THEN direct Tailnet access to port 13305 fails
- AND malformed authorization fails before model download
- AND Lemonade is inactive
- AND the Qwen service remains healthy without a restart loop
