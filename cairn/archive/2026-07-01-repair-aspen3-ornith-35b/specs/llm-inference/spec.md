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
