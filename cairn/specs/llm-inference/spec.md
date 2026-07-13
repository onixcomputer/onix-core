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

### Requirement: Aspen1 Ornith BF16 trial

r[onix.aspen1.ornith.bf16] The `aspen1` Lemonade inventory MUST register and pull the official Ornith 1.0 35B BF16 GGUF while retaining the working 35B Q4_K_M model as a rollback target.

#### Scenario: BF16 is added without removing Q4

r[onix.aspen1.ornith.bf16.inventory]
- GIVEN the `aspen1` Lemonade service inventory
- WHEN its custom models and pull list are evaluated
- THEN `user.Ornith-1.0-35B-BF16` is included
- AND `user.Ornith-1.0-35B-Q4_K_M` remains included
- AND the broken `user.Ornith-1.0-35B-Q8_0` endpoint is not introduced

### Requirement: BF16 trial has positive and negative live validation

r[onix.aspen1.ornith.bf16.validation] The BF16 trial MUST verify useful generated output and service health, and MUST preserve the Q4 endpoint when BF16 download, load, inference, or resource checks fail.

#### Scenario: BF16 produces a useful response

r[onix.aspen1.ornith.bf16.validation.positive]
- GIVEN the BF16 model is downloaded and the Lemonade service is healthy
- WHEN a live non-thinking chat probe asks `What is 2+2?`
- THEN the response content is `4`
- AND the request completes successfully

#### Scenario: BF16 trial fails safely

r[onix.aspen1.ornith.bf16.validation.negative]
- GIVEN the BF16 model cannot download, load, generate useful output, or remain within available memory
- WHEN the trial result is evaluated
- THEN BF16 is not accepted as the working Aspen1 model
- AND the live-validated Q4 endpoint remains available
