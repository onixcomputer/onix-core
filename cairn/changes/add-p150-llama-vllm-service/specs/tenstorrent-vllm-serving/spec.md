## ADDED Requirements

### Requirement: Llama-3.1-8B-Instruct supplements the existing P150 services

r[onix.tenstorrent.vllm.p150_llama] The `britton-desktop` deployment MUST serve `meta-llama/Llama-3.1-8B-Instruct` through Tenstorrent's digest-pinned P150 vLLM image on physical card 1, MUST keep VibeThinker continuously available on physical card 0, MUST preserve CPU Supra on port 13306, and MUST NOT configure undocumented `p150x2` aggregation.

#### Scenario: Three model endpoints are available concurrently

- GIVEN VibeThinker is healthy on physical card 0, CPU Supra is healthy, and the gated Llama weights are available
- WHEN Llama-3.1-8B-Instruct starts through the P150 vLLM container on physical card 1
- THEN VibeThinker remains active on port 13305
- AND Supra remains active on port 13306
- AND Llama serves an OpenAI-compatible completion on port 8000
- AND journals show no device-lock collision or service restart loop

#### Scenario: Gated model credential is unavailable

- GIVEN no authorized Hugging Face token is deployed
- WHEN the Llama service is evaluated or activated
- THEN the token is not substituted into the Nix store, command line, or logs
- AND the deployment reports the exact missing-credential blocker instead of replacing or stopping VibeThinker

### Requirement: P150 vLLM credentials and cache are private

r[onix.tenstorrent.vllm.secrets] The Llama vLLM service MUST read `HF_TOKEN` from a root-owned deployed secret environment file, MUST reject empty and stock SOPS placeholder values during generation, and MUST keep downloaded model/cache state in a service-private mutable directory outside the Nix store.

#### Scenario: Authorized token is deployed

- GIVEN an operator supplies an authorized Hugging Face token through the clan prompt
- WHEN clan generates and deploys the service environment file
- THEN the file contains the `HF_TOKEN` environment assignment with root-only permissions
- AND the OCI service receives the file without embedding its contents in evaluated configuration
