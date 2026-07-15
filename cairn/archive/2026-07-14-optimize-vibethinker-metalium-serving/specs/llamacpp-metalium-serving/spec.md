# llama.cpp Metalium Serving Delta

## ADDED Requirements

### Requirement: Metalium is a selectable llama.cpp backend

r[onix.llamacpp_server.metalium_backend] The schema-driven `llamacpp-server` service MUST select the pinned `llama-cpp-metalium` package when configured with the Metalium backend and MUST expose an explicit non-negative Metalium device identifier.

#### Scenario: Metalium backend selects a physical device

- GIVEN a valid `llamacpp-server` instance configured with the Metalium backend
- WHEN NixOS evaluates the generated systemd service
- THEN the service command uses the pinned Metalium `llama-server`
- AND the service environment selects the configured physical device identifier

### Requirement: Metalium serving rejects unsupported runtime combinations

r[onix.llamacpp_server.metalium_safety] A Metalium `llamacpp-server` instance MUST keep KV cache on the CPU, MUST disable Metalium trace capture, MUST reject flash attention, MUST reject explicit quantized KV-cache types, and MUST remove `GGML_METALIUM_MESH_SHAPE` from its service environment.

#### Scenario: Safe Metalium configuration evaluates

- GIVEN a Metalium instance with flash attention disabled and no KV-cache quantization overrides
- WHEN the module assertions are evaluated
- THEN the configuration succeeds
- AND the generated command contains `--no-kv-offload`

#### Scenario: Unsupported Metalium cache configuration is rejected

- GIVEN a Metalium instance with flash attention enabled or an explicit KV-cache quantization type
- WHEN the module assertions are evaluated
- THEN evaluation reports a configuration error

### Requirement: VibeThinker uses the measured single-device path

r[onix.vibethinker.metalium_serving] The `britton-desktop` VibeThinker service MUST use Q8_0 weights on Blackhole device 0 with batch and physical batch size 512, one parallel slot, CPU F16 KV cache, trace capture disabled, and no llama.cpp mesh aggregation while the host's P150x2 descriptor remains available to native TT-NN and TT-Metal workloads.

#### Scenario: VibeThinker service uses the latency configuration

- GIVEN the `britton-desktop` service inventory
- WHEN the VibeThinker systemd unit is generated
- THEN it uses the Metalium backend and selects device 0
- AND it does not enable flash attention, quantized KV cache, trace capture, or llama.cpp mesh aggregation
- AND the Tenstorrent host environment still exports the P150x2 mesh descriptor
