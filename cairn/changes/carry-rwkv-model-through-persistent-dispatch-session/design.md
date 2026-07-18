# Design: Persistent logical RWKV dispatch session

## Goal and completion evidence

Starting from the accepted physical-seeded token-two model state, execute the third token and its greedily selected fourth-token continuation through one logical device-free dispatch session. Completion requires one immutable sequence identity, calls `0..23`, token indices `2` then `3`, layers `0..11` per token, exact same-layer response-to-next-request state continuity, a clean close only after all calls, independent BF16-oracle agreement, retained/reset/transposed controls, deterministic receipts, historical receipt preservation, and no process/device surface.

False completion includes two independent one-token sessions, resetting call ordinals at the token boundary, merely concatenating transcripts after execution, accepting caller-supplied fourth-token identity, carrying state only in the model without validating framed BF16 continuity, accepting a response after timeout/interruption, retrying or reconnecting automatically, or claiming an OS-persistent/Metalium transport.

## Portfolio decision

Four mechanisms were considered:

1. A pure `prepare -> accept | fault -> close` session state machine with one pending request and per-layer returned-state memory. This directly proves lifecycle and continuity invariants and survives as the functional core for a later imperative transport shell.
2. A post-hoc transcript validator. This can detect some ordering errors but cannot prove that output/state were withheld until the pending response was accepted, so it is weaker than the goal.
3. An embedded model callback/trait. This hides transport ordering inside numerical recurrence and repeats the coupling rejected at the stable-ABI rung.
4. A real CPU subprocess or socket sidecar. This introduces process lifecycle and transport failure surface before the pure contract is closed and is outside this device-free rung.

The pure state machine is selected. An advisory review agreed with the single-pending lifecycle but suggested queues, exponential backoff, and state reset on close. Those suggestions are rejected here: the canonical workload is strictly serial, retry/backoff is explicitly forbidden, and close must preserve a deterministic terminal summary rather than silently reset authority.

## Functional core

`PersistentCpuDispatchSession` owns only in-memory authority:

- immutable sequence identity;
- first token index and exact token count;
- next call ordinal;
- one optional pending decoded request and frame;
- the last accepted BF16 post-state for each logical layer;
- accepted steps for deterministic transcript reduction; and
- open, faulted, or closed terminal state.

`prepare` derives the sole expected token and layer from the next call. It rejects any caller drift. Starting with the second dispatched token, it requires the request's BF16-canonicalized pre-state to equal the last accepted response post-state for that same layer. It creates exactly one pending request but does not expose output/state.

A separate pure CPU emulator decodes the request frame, evaluates the shared recurrence, and emits a canonical response frame. `accept` decodes and validates the response against the exact pending request before returning output/state, records that layer's post-state, and advances authority exactly once. Invalid response acceptance transitions the session to a terminal fault. A timeout or interruption is an explicit injected fault event, not a clock or process operation. Faulted sessions reject every later action. `close` succeeds only with no pending request and exactly twenty-four accepted calls.

## Model composition

The fixed replay reconstructs the accepted physical-seeded token-two state and validates the prior real-model dispatch receipt. It then branches retained, reset-all-matrices, and per-head-transposed paths. Each path uses one session across two tokens:

- token index `2`, model token ID `2`, calls `0..11`;
- audited top-two logits select the next model token ID;
- token index `3`, that exact selected token ID, calls `12..23`;
- clean session close and transcript reduction.

An independent route applies the same BF16 transport boundaries but uses the separately ordered recurrence oracle for both tokens. Complete raw outputs, matrix post-states, layer outputs, recurrent state, final hidden state, logits, rankings, frame identities, continuity identities, and terminal session summary are compared and fingerprinted.

## Negative validation

Unit and package checks must reject:

- wrong initial token, skipped token, repeated token, or wrong layer;
- call-ordinal reset at the token boundary;
- changed BF16 same-layer pre-state on the second dispatched token;
- prepare while a response is pending;
- stale, duplicate, reordered, changed-authority, changed-request, malformed, truncated, trailing, or non-finite response frames;
- timeout or interruption followed by response acceptance, retry, reconnect, close-as-success, or another call;
- close with a pending request, too few calls, or too many calls;
- changed physical evidence, prior receipt, invocation vector, model, token selection, or source surface.

Positive tests cover exact two-token completion, per-layer state continuity, deterministic replay, clean close, independent-oracle agreement, and retained-state sensitivity.

## Claim boundary

This rung proves that one pure logical session can carry canonical model-derived dispatch authority and host-returned matrix state across two complete model tokens. It does not create or execute a persistent process, socket, Metalium device, physical WKV call, complete physical layer/model, hardware-backed generation, serving, throughput, latency, or general P150 claim. The accepted physical session remains `unsafe`; new physical call count remains zero; tasks `30` and `64` remain terminal and unusable.

## Validation evidence

The fixed replay emits a 78,154-byte canonical receipt with BLAKE3 `31f3e1dea79fb152ddb7ae5cc9049b97b8b38ca2a187964ee9edac5f5d45feae`. It binds token IDs `[1,2,2,2]`, dispatched token indices `[2,3]`, twenty-four CPU dispatch calls, one historical physical call, zero new physical calls, the terminal `unsafe` outcome, and the accepted prior model-dispatch receipt `81c3b5c9904d2469b89d3f6732609514996fbe910a0c9ff0c150fb6044832b5d`.

The retained, reset, and transposed sessions each close cleanly after twenty-four calls, record twelve exact same-layer state-continuity checks across the token boundary, and contain twenty-four unique 107,588-byte request hashes plus twenty-four unique 99,940-byte response hashes. Their sequence identities are `44430cdb0e204cab653e913b781b40b0d1d9652f1f55b8ee49c0c937b014e35d`, `903b16ad4f679f93c77a42eaa578129ea514de839a7e4a1767ab3fb3906a1d25`, and `77c9d1fa2737db58eee38cb73fcb6741dd00845bff08386338128359cdb5543e`; transcript identities are `1be98ce2f01f8d56b92251fe6015439cd59acb895996bb702c5b0849b2844334`, `d20f1192aeaef363f7fc331fd91484bfa404194a561ca6434c4d2468a4b9d1c7`, and `140f9dfc8c8b8004c1060d1cd1752c87fdb514151c0a428c0a8ede7e4fbfbf07`.

Both retained dispatched tokens and both independent BF16-oracle tokens rank token `2` first and token `33` second. The oracle-selected token `2` is the exact fourth-token input for every branch. Third-token dispatched/oracle maximum deviations are raw WKV `0.001953125`, matrix post-state `0.0009765625`, layer/final output `0.0001604557`, final hidden `0.00035476685`, logits `0.00018692017`, and complete recurrent state `0.0009765625`. Fourth-token deviations are raw WKV `0.0`, matrix post-state `0.00048828125`, layer/final output `0.000002861023`, final hidden `0.000011444092`, logits `0.0000104904175`, and complete recurrent state `0.00048828125`, below the fixed `0.005` ceiling.

The retained fourth token differs from reset by `118.36631` in final output, `14.686736` in logits, and `55.000004` in complete state. It differs from per-head transpose by `21.618242`, `24.41396`, and `54.99176`. Reset ranks `[92,11]` then `[11,0]`; transpose ranks `[47,1753]` then `[47,267]`, while every branch consumes the retained oracle-selected fourth-token input ID `2` to avoid control confounding.

The physical seed attention, channel, matrix, and complete-state identities remain `ad0016542abe85df264a65b9083b30fe61b844cd568a8696fe457d853c47a0fb`, `9e938d7dfbfc02c0b16a064a28c7fcbb10dc4294d8b00fea7fd3aa8af22a5c95`, `b0984844f004f2a92bd06efcdc5dddb692e69948b9bb0d4599c4d5c3c6ce4afb`, and `07639ace76eb47cd7ce733b0754d1905af3c117701821850da9abfc695d232dd`.

Positive and negative unit tests exercise exact completion, wrong token/layer order, changed same-layer pre-state, stale/truncated/duplicate responses, a second prepare while pending, an extra call, timeout, interruption, premature close, and calls after fault or close. Invalid responses fault before output/state exposure; timeout and interruption are injected pure events and cannot retry, reconnect, or emit a clean close. Close independently verifies exact call and continuity counts plus unique request and response frames.

The dispatch core, model composition core, library export, imperative shell, package definition, flake check, and dependent boundary check have BLAKE3 identities `5fac531ed399f1cf1307f1de99d85112a97f516e199893df1d0dfb28a3e42f86`, `60bd7f217a0c0795b06e036185cd41c9347cdba3d651c1f9f6b902e55df260d1`, `ab367e4faf687262b269873f650855265b8ee1a8e6ce41a30a8042f583e73499`, `2841b69722c1afb73753c781042a4bc9385935a7fb68487391aea2690c345147`, `bfc2a0c75e8c0027764c4e34e426d0cc6e41d5f06ed43dbe22bcd1c9f7d6d961`, `a0d250c3dcdd5c51733afedd67646ecc62504c1622017895722c7e5fa6d4786e`, and `1faa48855c8beb0d0de0696d84687fab274e47e33df3b103f4001cec25657bce`.

Focused output is `/nix/store/r8wkqa37jjf04w412qvsmsx4028yq5gp-rwkv-ttwkv7-persistent-observed-model-dispatch`. Historical outputs include `/nix/store/0wl0hfglyikmlrzxbkc3fggvabp499dy-rwkv-ttwkv7-observed-model-dispatch`, `/nix/store/mlim3x7nahagshff7skjfb4sbfm7pp3w-rwkv-ttwkv7-dispatch-abi`, `/nix/store/ja5py3ap4ffr3s7ygpgi7bry7c1sjbdy-rwkv-ttwkv7-observed-model-carry`, `/nix/store/mg12cpfrdc32kb9q5q46n3dgd0ygacyy-rwkv-ttwkv7-observed-state-carry`, `/nix/store/xxc6j94m54vddjic65az09zn5rmkrig6-rwkv-ttwkv7-observed-layer-replay`, `/nix/store/rz7vp2ppqiyciivp9ynqjzgyzmcj057x-rwkv-layer-harness-torch-equation-parity`, `/nix/store/lx01h5230815np6g0brrj2489nypgxfs-rwkv-ttwkv7-host-layout-check`, `/nix/store/zlxrg646lynxnm8ggfl63y044z5fkl1m-rwkv-ttwkv7-decode-reader-check`, and `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`. The runtime package `/nix/store/4dva4df7cwnjrar9jjw965m4s31wdrz8-rwkv-layer-harness-0.1.0` has fifteen closure paths, contains neither Python nor PyTorch, and excludes physical evidence.

Historical receipt identities remain byte-identical: model dispatch `81c3b5c9904d2469b89d3f6732609514996fbe910a0c9ff0c150fb6044832b5d`, dispatch ABI `65ab5583647dc79b1d1c78870cedccd6f556a58264dd9b9640c9214f010fe431`, model carry `74306bd245d0bf3b4de9ce5c5f0736edcb516ac9556bc67e7c8116653de973ed`, state carry `58e433a04a10319293b18d6003659b53a04a95e9cf9cc7b540c2448c98ed6a33`, and observed layer `0f2e08a9966672ab8d076ec2a601e336c0e0022ea4af023e472a7bbc05ba6d18`.

The mechanically rebuilt, still-`not_run` boundary package is `/nix/store/5p2m5lvv1gvdg7nv616cym8w18xq2lvg-rwkv-ttwkv7-boundary-device-0.2.0`. Its plan ID is `134962b07ade1ac827e3929b7e538fcac1a87591973634fcfec11635966a8818`; plan and not-run receipts have BLAKE3 identities `b08b01098558d837a5160331fd01355711b2725c80caa8f5381a980d8dc0b46e` and `190cdca1fda51016293ba83276041b74c542205b9fa9e68b884ef6e21a37951b`. No runbook, process transport, hardware process, device, or owner-service action occurred. Clean detached-worktree Cairn validation reports `valid: true` with no issues or substance issues; proposal, design, and tasks gates pass. Clippy remains unavailable because the evaluated development shell does not provide `cargo` (`exec: cargo: not found`), while Rust compilation, unit tests, install checks, and all focused and historical Nix checks pass.
