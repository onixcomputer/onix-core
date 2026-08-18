## ADDED Requirements

### Requirement: Physical-seeded RWKV tokens traverse one persistent logical dispatch session
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_model_dispatch] The RWKV harness SHALL provide a device-free pure dispatch-session state machine and a deterministic fixed-evidence replay that route every WKV call for the third token and its greedily selected fourth-token continuation through one canonical session, with exact sequence/call/token/layer authority, same-layer BF16 state continuity, independent recurrence and untied-head oracles, terminal fault semantics, complete-vector receipts, retained-state controls, and no process or hardware access.

#### Scenario: Two complete model tokens share one session
- GIVEN the pinned checkpoint, exact accepted physical-seeded token-two model state, and one immutable dispatch sequence identity
- WHEN the third token and its greedily selected fourth-token continuation are evaluated
- THEN exactly twenty-four ordered request-bound responses SHALL be accepted with calls `0..23`, token indices `2` then `3`, and layers `0..11` for each token
- AND one clean close SHALL occur only after every expected response is accepted

#### Scenario: Returned state crosses the token boundary
- GIVEN each layer's accepted third-token response contains one canonical BF16 matrix post-state
- WHEN the same layer prepares its fourth-token request
- THEN the request pre-state SHALL equal that exact accepted post-state after canonical BF16 framing
- AND changed, reset, transposed, missing, or cross-layer state SHALL be rejected before a request becomes pending

#### Scenario: Dispatched tokens agree with independent oracles
- GIVEN retained, reset-all-matrices, and per-head-transposed branches from the same accepted physical-seeded model state
- WHEN both tokens complete through their respective logical sessions
- THEN retained complete raw outputs, post-states, layer outputs, recurrent state, final hidden state, logits, and top-two rankings SHALL agree with the independently ordered BF16 oracle within fixed named bounds
- AND reset and transposed controls SHALL remain observably distinct from retained execution

#### Scenario: Pending response authority fails closed
- GIVEN one exact canonical request is pending
- WHEN a stale, duplicate, reordered, changed-authority, changed-request, malformed, truncated, trailing, or non-finite response is supplied
- THEN no changed output or post-state SHALL be returned to the model
- AND the session SHALL enter a terminal fault that rejects every subsequent call and clean close

#### Scenario: Timeout and interruption are terminal events
- GIVEN an open session with or without one pending request
- WHEN the pure shell injects a timeout or interruption event
- THEN the session SHALL become terminal without retry, backoff, reconnect, sequence reuse, response acceptance, or state reset
- AND a new session, process, or hardware action SHALL NOT be created implicitly

#### Scenario: Ordering and close drift are rejected
- GIVEN the exact two-token session authority
- WHEN a caller changes token order, layer order, call progression, pending-call cardinality, expected call count, or close position
- THEN the state machine SHALL reject the transition without producing a successful terminal summary

#### Scenario: Persistent-session validation remains device-free
- GIVEN the sole `--evidence-root PATH` replay, package-owned evidence, and accepted historical receipts
- WHEN deterministic replay, negative fixtures, Nix checks, and Cairn gates run
- THEN no process API, socket, Metalium device API, owner-service action, runbook, physical WKV call, retry, reconnect, or hardware authorization SHALL occur
- AND the receipt SHALL preserve the terminal `unsafe` classification and record zero new physical calls
