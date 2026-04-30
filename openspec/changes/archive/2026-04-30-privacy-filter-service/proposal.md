## Why

The repo can deploy generative and embedding inference today, but it cannot deploy Hugging Face token-classification services such as `openai/privacy-filter`. We want a reusable on-prem service module for PII redaction so an Aspen can host Privacy Filter as a first-class managed service instead of an ad-hoc one-off container.

## What Changes

- Add a new `privacy-filter` clan service module for Hugging Face token-classification inference with a simple HTTP API for redact/detect requests
- Package the service around a reusable runtime that can load `openai/privacy-filter` from Hugging Face and run on CPU or ROCm-backed GPU hosts
- Add typed schema/settings support so service instances validate through the existing Nickel inventory contracts
- Add an inventory service instance that deploys Privacy Filter to `aspen1` by default, with host/port/model/runtime settings managed from `inventory/services/services.ncl`
- Document operational constraints such as model cache location, device selection, and API shape for downstream callers

## Capabilities

### New Capabilities
- `privacy-filter-service`: Managed token-classification inference service for privacy redaction models with a stable local HTTP API
- `privacy-filter-module-schema`: Inventory-configurable schema for privacy-filter service instances, including runtime, device, network, and model settings

### Modified Capabilities

## Impact

- `modules/privacy-filter/` — new service module, schema, and runtime wiring
- `modules/default.nix` — register the new service module
- `inventory/services/settings-contracts.ncl` — include the new module schema through the existing auto-derived registry
- `inventory/services/services.ncl` — add a `privacy-filter` service instance targeting `aspen1`
- `pkgs/` or module-local packaging — runtime wrapper/container definition for Hugging Face Privacy Filter inference
- Downstream clients — local callers can send redact/detect requests to the managed HTTP endpoint instead of shelling out or embedding model runtime logic
