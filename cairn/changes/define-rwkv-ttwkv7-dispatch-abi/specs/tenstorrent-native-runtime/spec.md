# Tenstorrent Native Runtime Specification Delta

## ADDED Requirements

### Requirement: RWKV ttWKV7 dispatch ABI
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_dispatch_abi] The RWKV harness SHALL expose a versioned device-free ttWKV7 request/response ABI with canonical little-endian BF16 frames, exact sequence/call/token/layer authority, reviewed dimensions, request-bound responses, retained per-layer state, deterministic transcript receipts, and fail-closed malformed-frame validation.

#### Scenario: Retained state traverses every logical layer
- GIVEN twelve independent zero matrix states and deterministic WKV inputs for two ordered tokens
- WHEN the device-free CPU dispatcher executes the canonical requests in increasing call order
- THEN exactly twenty-four request-bound responses are accepted and every second-token request consumes its layer's first-token post-state

#### Scenario: A stale or reordered response is supplied
- GIVEN a canonical request awaiting one exact response
- WHEN a response changes the sequence, request identity, call ordinal, token ordinal, or layer ordinal
- THEN validation rejects the response before its output or post-state can be consumed

#### Scenario: A frame is malformed
- GIVEN a request or response with changed magic, schema, dimensions, payload length, finiteness, or trailing bytes
- WHEN the frame decoder validates the canonical ABI
- THEN it rejects the frame instead of accepting a partial or reinterpreted payload

#### Scenario: Dispatch validation runs device-free
- GIVEN the fixed argument-free dispatch-ABI check
- WHEN its deterministic replay and negative fixtures run
- THEN no process API, Metalium device API, owner-service action, physical execution, or hardware authorization is used or claimed
