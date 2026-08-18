# Llamacpp Metalium Serving Delta

## MODIFIED Requirements

### Requirement: Metalium serving rejects unsupported runtime combinations

r[onix.llamacpp_server.metalium_safety] A Metalium `llamacpp-server` instance MUST keep KV cache on the CPU, MUST reject flash attention, MUST reject explicit quantized KV-cache types, MUST remove `GGML_METALIUM_MESH_SHAPE` from its service environment, and MUST keep experimental Metalium trace replay disabled by default unless that individual service satisfies the reviewed per-service evidence and rollback boundary.

#### Scenario: Safe default Metalium configuration evaluates

- GIVEN a Metalium instance with flash attention disabled, no KV-cache quantization overrides, and no trace opt-in
- WHEN the module assertions are evaluated
- THEN the configuration succeeds
- AND the generated command contains `--no-kv-offload`
- AND the service environment disables Metalium trace replay

#### Scenario: Evidence-gated trace opt-in evaluates

- GIVEN an individual Metalium service whose fixed-input trial demonstrated correct output and a material warm-performance improvement
- WHEN that service explicitly opts into Metalium trace replay
- THEN its generated environment enables trace replay without changing physical-device or mutable-state isolation

#### Scenario: Unsupported Metalium cache configuration is rejected

- GIVEN a Metalium instance with flash attention enabled or an explicit KV-cache quantization type
- WHEN the module assertions are evaluated
- THEN evaluation reports a configuration error
