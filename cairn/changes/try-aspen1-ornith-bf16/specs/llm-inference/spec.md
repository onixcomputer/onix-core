# LLM Inference Specification Delta

## Purpose

Trial the official Ornith 1.0 35B BF16 GGUF on `aspen1` without removing the live-validated Q4 fallback.

## ADDED Requirements

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
