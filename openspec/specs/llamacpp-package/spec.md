# Llamacpp Package Specification

## Purpose

This specification records requirements synced from OpenSpec change `distributed-llm-inference`.

## Requirements

<!-- synced from openspec change: distributed-llm-inference -->
## ADDED Requirements

### Requirement: llama.cpp built with ROCm HIP and RPC support
The system SHALL provide a Nix package that builds llama.cpp from source with ROCm HIP targeting gfx1151, RPC backend, and rocWMMA flash attention support. The package MUST produce both `llama-server` and `rpc-server` binaries.

#### Scenario: Package builds with required cmake flags
- **WHEN** the package is built via `nix build`
- **THEN** cmake is invoked with `-DGGML_HIP=ON`, `-DAMDGPU_TARGETS="gfx1151"`, `-DGGML_RPC=ON`, and `-DGGML_HIP_ROCWMMA_FATTN=ON`

#### Scenario: Package outputs include required binaries
- **WHEN** the package build completes
- **THEN** the output contains `bin/llama-server` and `bin/rpc-server` executables

### Requirement: Package defined as a Nix overlay
The package SHALL be defined as a Nix overlay in the flake so other modules can reference it as `pkgs.llamacpp-rocm-rpc`.

#### Scenario: Overlay makes package available
- **WHEN** a NixOS module references `pkgs.llamacpp-rocm-rpc`
- **THEN** the package resolves to the custom llama.cpp build with ROCm, RPC, and flash attention

### Requirement: Package pins a specific llama.cpp version
The package SHALL pin a specific llama.cpp git revision or release tag to ensure reproducible builds.

#### Scenario: Reproducible build across machines
- **WHEN** aspen1 and aspen2 both build the package
- **THEN** both produce the identical llama.cpp binary (same store path)
