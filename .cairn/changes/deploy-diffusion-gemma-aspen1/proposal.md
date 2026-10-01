## Why

Deploy the actual DiffusionGemma model on Aspen1 without consuming the occupied Spark cluster. Aspen1 has a Radeon 8060S, a verified 96 GiB GTT pool and approximately 118 GiB available system memory. Aspen2 has substantially less headroom.

## What Changes

- Add an Aspen1-only persistent DiffusionGemma service with an independent loopback API and dedicated state.
- Pin the original Google BF16 model and an AMD gfx1151 runtime; preserve the structured-read functionality from vLLM PR 57250.
- Prevent the enabled but stopped Aspen1 Qwen service from claiming the GPU after service restarts or reboot. Preserve its model files, Aspen2, and existing mesh routing.

## Impact

- **Files**: Aspen1 machine configuration and its new deployment files; this native Cairn change and measured deployment receipt.
- **Testing**: Native ROCm BF16 execution, real DiffusionGemma text and seeded-canvas inference, API health, persistent unit configuration, and targeted Nix/Cairn validation.
- **Boundary**: Deploy only the selected service closure and its explicit GPU-ownership change. No full-host activation, flake update, Spark changes, public listener, or unrelated service restart.
