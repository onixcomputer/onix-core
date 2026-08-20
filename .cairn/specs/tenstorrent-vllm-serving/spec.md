# Tenstorrent Qwen Serving Specification

## Purpose

Defines the admitted serialized Qwen3.8-27B service on `britton-desktop`.

## Requirements

### Requirement: Qwen3.8-27B owns the P150x2 mesh

r[onix.tenstorrent.p150x2_qwen.deployment] The `britton-desktop` deployment MUST run the pinned Qwen3.8-27B package as `qwen38-p150x2.service`, MUST use physical devices 0 and 1 as one `1x2` mesh, MUST serve only on loopback port 8000, and MUST start through `multi-user.target`.

#### Scenario: The declarative service starts after reboot

- GIVEN the pinned model snapshot and both device nodes exist
- WHEN `britton-desktop` reaches `multi-user.target`
- THEN `qwen38-p150x2.service` starts from the pinned `tenstorrent.nix` package
- AND `/healthz` reports the Qwen3.8-27B model as healthy
- AND the OpenAI-compatible endpoint listens on `127.0.0.1:8000`

#### Scenario: A required model or device path is absent

- GIVEN the model snapshot or either device node is absent
- WHEN systemd evaluates the service conditions
- THEN the service does not start
- AND systemd records the failed condition without selecting another model service

### Requirement: Qwen serving remains bounded and serialized

r[onix.tenstorrent.p150x2_qwen.contract] The service MUST use greedy non-streaming generation, MUST serialize requests, MUST limit prompt plus generation to 2048 tokens, and MUST limit one generation to 64 tokens.

#### Scenario: A valid bounded request completes

- GIVEN the service is healthy
- WHEN one valid request asks for no more than 64 generated tokens within the 2048-token sequence limit
- THEN the service returns one OpenAI-compatible response
- AND no second accelerator request runs concurrently

#### Scenario: An unsupported request is rejected

- GIVEN a request asks for streaming, sampling, multiple choices, excessive generation, or an excessive sequence
- WHEN the service validates the request
- THEN it returns the documented client error
- AND it does not execute the rejected request on either device

### Requirement: Retired accelerator services stay absent

r[onix.tenstorrent.p150x2_qwen.exclusivity] The generated host configuration MUST NOT contain the former VibeThinker service or the former P150 Llama container, and the Qwen unit MUST conflict with both stale unit names during activation.

#### Scenario: Host configuration is evaluated

- GIVEN the `britton-desktop` NixOS configuration
- WHEN systemd services and OCI containers are inspected
- THEN `llamacpp-server-vibethinker-britton-desktop.service` is absent
- AND `docker-tt-inference-server-llama-3-1-8b-instruct-p150.service` is absent
- AND the old Llama OCI container is absent
- AND the Qwen unit lists both stale names as conflicts

### Requirement: The reusable P150 vLLM module remains validated

r[onix.tenstorrent.vllm.p150_llama] The reusable `tt-inference-server` module MUST keep its digest-pinned P150 configuration and physical-device isolation, but `britton-desktop` MUST NOT assign an instance while Qwen owns both P150 devices.

#### Scenario: A module fixture configures one P150

- GIVEN a valid fixture selects one physical P150
- WHEN the module configuration is evaluated
- THEN the OCI command uses the pinned image and P150 device profile
- AND only the selected device node is passed to the container

### Requirement: Reusable vLLM credentials remain private

r[onix.tenstorrent.vllm.secrets] The reusable module MUST read `HF_TOKEN` from a root-owned deployed secret environment file and MUST keep the token out of the Nix store and command line.

#### Scenario: An authorized fixture credential is deployed

- GIVEN an operator supplies a token through Clan vars
- WHEN the module generates its environment file
- THEN the file has root-only permissions
- AND the evaluated configuration does not contain the token
