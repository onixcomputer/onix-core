# LLM Inference Specification Delta

## REMOVED Requirements

### Requirement: Aspen2 serves uncensored Qwen3.8 Flash Next
r[onix.aspen2.qwen_flash.serving] `aspen2` MUST serve the same revision-pinned OrcaRouter Qwen3.8 Flash Next Uncensored IQ4_XS GGUF and multimodal projector as `aspen1`. The direct server MUST bind to loopback port 13305. The `aspen2` mesh-llm joiner MUST route to that service.

### Requirement: Aspen2 Qwen inference memory exclusivity
r[onix.aspen2.qwen_flash.exclusivity] `aspen2` MUST NOT run Lemonade alongside Qwen3.8 Flash Next because both model services compete for the same unified-memory capacity.

### Requirement: Aspen2 Qwen3.8 Flash Next live validation
r[onix.aspen2.qwen_flash.validation] The deployment MUST include positive and negative live validation of the Qwen3.8 Flash Next service on `aspen2`.

Removal rationale: the model and its 32K context need 65,159 MiB, more than the 62 GiB `aspen2` has, so the unit cannot start. The operator dropped it on 2026-10-21; `aspen2` keeps providing research tools to the mesh.
