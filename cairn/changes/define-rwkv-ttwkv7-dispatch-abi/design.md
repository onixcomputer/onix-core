# Design: RWKV ttWKV7 dispatch ABI

## Goal

Create the smallest stable device-free contract between host model orchestration and one WKV recurrence call. Completion requires canonical request/response bytes, deterministic retained-state replay over twelve layers, fail-closed negative tests, a fixed receipt, and unchanged historical observed-layer/state/model receipts.

## Portfolio decision

Four mechanisms were considered:

1. A pure prepare-request / validate-response / finish-step state machine with a thin dispatcher loop.
2. A trait callback embedded directly in model recurrence.
3. A JSON subprocess protocol.
4. A fixed CPU backend enum.

The state-machine design is selected because it keeps framing, validation, and transcript logic deterministic and independently testable while allowing a later imperative shell to own a persistent Metalium device. An embedded callback obscures the side-effect boundary, a subprocess protocol prematurely adds process ownership and inefficient vector JSON, and a fixed enum does not define an extensible ABI. An advisory independent review ranked the same mechanism first and emphasized stale, ordering, duplication, shape, finiteness, token-order, and receipt tests.

## Frame contract

A request frame contains:

- fixed request magic and schema version;
- a fixed 32-byte sequence identifier;
- call, token, and layer ordinals;
- reviewed head-count, head-size, and hidden-size dimensions;
- six BF16 little-endian WKV input vectors in production ttWKV7 `a,w,k,v,r,b` order; and
- one BF16 little-endian retained matrix pre-state.

A response frame contains:

- fixed response magic and schema version;
- the same sequence and ordinals;
- the reviewed dimensions;
- the BLAKE3 identity of the exact canonical request frame;
- one BF16 little-endian raw WKV output; and
- one BF16 little-endian matrix post-state.

The decoder consumes the exact expected byte count and rejects missing or trailing bytes. Every identifier and dimension is validated before response vectors can be accepted.

## Functional core and shell

Pure cores construct canonical frames, decode and validate frames, emulate the response with the shared CPU recurrence, and reduce ordered frame identities into a transcript receipt. The argument-free binary is a thin shell that runs the deterministic fixture and writes canonical JSON. It reads no files, opens no process or device, and changes no service state.

## Deterministic retained-state fixture

The fixture uses reviewed checkpoint dimensions, twelve independent layer states, two token ordinals, and twenty-four strictly increasing call ordinals. Deterministic finite BF16 inputs vary by token, layer, channel, and input role. The second token consumes each first-token post-state. Reset and per-head transpose controls must diverge from the retained-state transcript.

## Validation and non-claims

Positive tests cover encode/decode round trips, CPU response validation, deterministic replay, all layer/token ordinals, and retained state. Negative tests mutate magic, version, sequence identity, request identity, call/token/layer ordinals, dimensions, payload lengths, trailing bytes, BF16 non-finite values, duplicate calls, stale responses, and state orientation.

This change does not establish model-derived dispatch inputs, persistent-process transport, Metalium initialization, physical execution, complete device layers, hardware token generation, serving, throughput, latency, or authorization for another hardware process. The physical session remains `unsafe`.

## Validation evidence

The argument-free replay emits a 5,234-byte canonical JSON receipt with BLAKE3 `65ab5583647dc79b1d1c78870cedccd6f556a58264dd9b9640c9214f010fe431`. Its sequence identity is `84e59e1fc4bb63ce7facc8ed34ee4d598335640ae157079fe879123fe03b6d59`, its length-delimited ordered request/response transcript is `ba8d3c401468f9ba751afb4baacc6c353242f2dd23f129a808f002b57d869ccf`, and every replay is byte-identical.

Each of the twenty-four request frames is 107,588 bytes and each response frame is 99,940 bytes. The receipt locks all twenty-four ordered request identities, all twenty-four response identities, production input order `a,w,k,v,r,b`, reviewed dimensions `H=12,S=64,C=768`, two token ordinals, twelve layer ordinals, and strictly increasing call ordinals. The retained, reset, and per-head-transposed final states have BLAKE3 identities `0820459ef5213b56abe294b26b63e4cf24c18c642089c8eebddea9352375a97a`, `b6a12cc17d7b02da79cda6451cbf09567411e54abd9958fba89a0d41e0c269dc`, and `946815abb8242af5035b426afd7746fab14b5d4511cb4408045f40d188f089f7`. Retained state diverges from reset by `0.0023040771` and from transposed state by `0.003791809`.

The dispatch core, shared library, observed composition core, shell, and package definition have BLAKE3 identities `f77ddb9e1e013490748d77bbe1c41fe84cadeed98b9035186cca36073a2b5492`, `c78eb7b8db5531186846cabde2d98e809c87887d0b977e06bd291c4d2cc7256a`, `c140f014c4897751e59502bdd7c3f8597b158396f2f60c67d458bb6c829ab9a4`, `48d39b03bc0b468bc3b06427928a4ba1a1cd6075e4f6f28854d18caaef7cfe61`, and `3d4827558ef90a6c23512de0b654667775e2274215642e7cd10057f76e0d8421`.

Positive and negative framing tests, deterministic replay, fixed invocation, source-surface rejection, and the focused check pass at `/nix/store/lmv00mvx73605pavvhcdbizzr8vwpmd2-rwkv-ttwkv7-dispatch-abi`. Historical model, state, and layer receipts remain exactly `74306bd245d0bf3b4de9ce5c5f0736edcb516ac9556bc67e7c8116653de973ed`, `58e433a04a10319293b18d6003659b53a04a95e9cf9cc7b540c2448c98ed6a33`, and `0f2e08a9966672ab8d076ec2a601e336c0e0022ea4af023e472a7bbc05ba6d18`. Framework parity, boundary-device compatibility, host layout, decode-reader ABI, architecture checks, and the archived runbook checker/self-test pass. The runtime package is `/nix/store/s2d4f6xjr0vs6mxzi1syysqkss21rp6p-rwkv-layer-harness-0.1.0`; its fifteen-path closure contains neither Python nor PyTorch and excludes physical evidence.

The mechanically rebuilt, still-`not_run` boundary package is `/nix/store/ip93nwm13qagra4l0igijdxmc06zx21y-rwkv-ttwkv7-boundary-device-0.2.0`. Its plan ID is `e801d50df9accac5edb89beee11c5638969aff95aa1bb5482f58a488137ce708`; plan and not-run receipts have BLAKE3 identities `2ec6e28974a96bd13c716b5c4adcbbff78d9fca1c3bed6cd7009111098d3c191` and `1d5e7d25fbb58d2ff685e542abca6c4b7ea55c9bcfd4a10be0664e9d7ef8eab1`. No runbook, hardware process, device, or owner-service action occurred. Clean detached-worktree Cairn validation reports `valid: true` with no issues or substance issues; proposal, design, and tasks gates all pass. Clippy remains unavailable because the evaluated repository development shell does not provide `cargo` (`exec: cargo: not found`), while Rust compilation, unit tests, install checks, and all relevant Nix checks pass.
