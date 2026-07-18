# Tenstorrent Native Runtime Specification Delta

## ADDED Requirements

### Requirement: Physical-seeded real-model ttWKV7 dispatch
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_model_dispatch] The RWKV harness SHALL reconstruct the accepted physical-seeded second-token model state and SHALL route every third-token logical layer through the canonical BF16 ttWKV7 dispatch ABI with exact call authority, retained per-layer state, independent recurrence and untied-head oracles, deterministic complete-vector receipts, reset/orientation controls, and no hardware or process access.

#### Scenario: Every third-token layer traverses framed dispatch
- GIVEN the pinned checkpoint, exact accepted physical layer-zero token-two output/state, and independently retained state for all twelve layers
- WHEN the third token is evaluated through the device-free dispatcher
- THEN exactly twelve ordered model-derived requests and request-bound responses are accepted and the framed result agrees with the independent BF16 oracle

#### Scenario: Retained all-layer state is reset or transposed
- GIVEN identical physical-seeded host state, checkpoint weights, and third-token embedding
- WHEN all twelve matrix states are reset or every per-head matrix is transposed before dispatch
- THEN complete recurrent state, final model output, and logits diverge from the retained path by the recorded positive floor

#### Scenario: Dispatch or evidence authority drifts
- GIVEN the fixed package-owned evidence and accepted prior receipts
- WHEN evidence bytes, sequence/call/token/layer authority, frame identity, response request binding, layer order, invocation shape, or prior receipt identity changes
- THEN validation fails before changed output or state is accepted

#### Scenario: Real-model dispatch remains device-free
- GIVEN the fixed `--evidence-root PATH` replay
- WHEN model-derived dispatch requests are evaluated
- THEN the CPU emulator performs every new WKV call without opening a process, Metalium device, or owner-service surface and without claiming hardware-backed token generation
