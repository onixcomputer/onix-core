# Design: One persistent Metalium RWKV dispatch session

## Success contract

Goal: consume one newly approved device-1 attempt and determine whether one persistent Metalium child can execute exactly twenty-four canonical model-derived ttWKV7 calls while a Rust host carries the physical outputs and state through the third and fourth tokens.

Observable completion requires all of the following:

- one immutable package, plan, readiness receipt, argument-free runbook, and static checker are committed and archived before invocation;
- one runbook invocation consumes one execution lock and launches one reviewed host command with no retry, reconnect, fallback, alternate runtime command, or second hardware attempt;
- the host launches exactly one C++ Metalium child, and the child creates exactly one device-1 MeshDevice for the complete session;
- calls `0..23` occur in token/layer order `(2,0)..(2,11),(3,0)..(3,11)` with fixed 107,588-byte requests and 99,940-byte responses;
- every response repeats exact authority, binds the exact request BLAKE3, is finite and complete, and is accepted before the host prepares the next layer;
- each fourth-token layer request carries that layer's exact physical third-token BF16 post-state, producing twelve independently checked continuity edges;
- one production DecodeL workload is enqueued per accepted request, for exactly twenty-four enqueues;
- every physical raw output and post-state passes the predeclared numerical ceiling against an independently ordered BF16 oracle, and both physical token rankings match their oracle rankings;
- complete transcripts, per-call metrics, final recurrent state, hidden vectors, logits, child summary, board evidence, owner evidence, raw logs, process accounting, restoration, and terminal classification are preserved under a fresh root; and
- the owner is restored and reaches the predeclared HTTP health status within the fixed recovery window for a safe success classification.

False completion includes a precomputed fourth-token transcript, CPU response substitution, a device reopen between calls, more or fewer than twenty-four physical enqueues, missing or duplicate frames, changed authority, non-finite/truncated/trailing payloads, state continuity inferred rather than byte-checked, process success without numerical evidence, numerical success without safe owner restoration, any retry/reconnect, or reuse of tasks `30`/`64` or their roots.

Allowed outcomes are `passed`, `failed`, `partial_diagnostic`, `unsafe`, or `not_run` according to the immutable typed plan and evidence. No result is upgraded after its health window.

## Architecture portfolio

The bounded portfolio budget is four mechanism families, one advisory review, one adversarial audit round, repository sources only, and deterministic checks as final authority.

| Family | Mechanism | State | Reason |
|---|---|---|---|
| persistent-subprocess | Rust retains model state; one fixed-frame C++ child owns Metalium | selected | Smallest design that lets physical responses derive subsequent layer and fourth-token requests while preserving the accepted ABI. |
| in-process-ffi | Rust calls a C++ Metalium library through FFI | blocked | Avoids a child but adds unsafe ABI/linking ownership and teardown complexity without stronger evidence for this rung. |
| cpp-monolith | Port the complete host model into the C++ runtime | blocked | Duplicates accepted model/token/head logic and weakens independent composition authority. |
| transcript-replay | Replay precomputed CPU request frames through one device owner | falsified | Cannot prove physical third-token output/state affected fourth-token requests. |

Adversarial audit must try to demonstrate CPU substitution, per-call device reopen, response/request mismatch, stale/duplicate/reordered/truncated frames, changed dimensions, non-finite results, continuity drift, early EOF, extra frames, child interruption, timeout, and owner restoration failure. Advisory review is non-authoritative.

## Functional core

Extend the canonical Rust dispatch state machine with explicit public prepare/accept boundaries and an opaque pure model driver. The driver owns reviewed weights, host recurrent state, token-local `v_first`, hidden state, oracle state, and pending layer preparation. `prepare` emits exactly one canonical request and enters a pending state. `accept` first validates the fixed response against that request, then computes the independent BF16 oracle, numerical metrics, attention suffix, residual/channel mix, layer transition, token head, and next-token embedding. No process, file, environment, socket, Metalium, or service operation is permitted in this core.

CPU tests shall feed the driver's requests through the existing CPU response encoder and reproduce the accepted persistent receipt. Negative tests shall reject stale, duplicate, reordered, truncated, trailing, non-finite, changed-authority, timeout, interruption, early-close, extra-call, and changed same-layer state paths.

Add an independent C++ frame core for canonical little-endian BF16 requests/responses. It shall fail closed on magic, schema, dimensions, authority, sizes, finite values, EOF, trailing data, request binding, order, call budget, and same-layer continuity. Its self-test and mutation fixtures run without creating a MeshDevice.

## Imperative shell

A dedicated Rust binary owns exactly one child process with piped stdin/stdout. It sends one fixed request, reads one exact response, and passes that response to the pure driver before proceeding. It closes stdin only after call twenty-four, requires clean child exit and a complete child summary, then writes host evidence atomically. There is no retry, reconnect, backoff, speculative request, concurrent pending call, or alternate backend.

The C++ server initializes one unit mesh after validating its complete immutable runtime state. It retains the MeshDevice across all calls. Each accepted request is converted through the production host-layout core, executes one DecodeL workload, and returns canonical BF16 output/post-state. Buffer/program construction may remain per call; device ownership must not. The child writes a summary binding device-open count, enqueue count, continuity count, request/response hashes, runtime arguments, kernel identities, and clean close.

A dedicated package pins the checkpoint, accepted physical seed evidence, host executable, C++ server, kernels, runtime closure, fixed device, fresh session/root, and argument vectors. Self-test and readiness checks use a CPU fake child and source-surface validation only; they shall not query a board, open a device, call a runbook, or modify the owner.

## Bounded execution

The approved attempt is limited to physical device `1`, one argument-free archived runbook invocation, one host command, one persistent Metalium child, one MeshDevice creation, twenty-four production DecodeL enqueues, a 1,800-second process timeout, a 10-second kill grace, a 2,100-second independent rollback timer, and a 600-second owner-health window. These values are named in typed configuration and static checks.

The runbook atomically creates a fresh root, installs classification/restoration traps before fallible preflight, validates immutable package/plan/readiness/source/host-key authority, captures board and owner preflight, arms independent rollback, isolates the owner, consumes the sole execution lock, runs the sole command, validates complete evidence, restores the owner, captures board/owner postflight, and classifies exactly once. Any preflight failure before isolation is `not_run`; any unsafe restoration remains `unsafe` even when later recovery succeeds.

## Validation and non-claims

Run baseline and post-change Rust/C++ unit tests, package/install checks, historical receipt checks, architecture/host-layout/decode-reader checks, wrapper/checker positive and negative tests, closure audits, deterministic replays, formatting, and clean detached-worktree Cairn validation.

Device-free validation locked package `/nix/store/iwwz6qm3zkvp916mxr4rzjvj6bkfqxic-rwkv-ttwkv7-persistent-device-0.1.0`, readiness output `/nix/store/yllfx0axffhb71ws7khzaabq1jydr9f2-rwkv-ttwkv7-persistent-device-check`, plan ID `9736c1b59a87d0af30a4b34087cdc56446cce69f6236accf6011b8eb5f165bf4`, and readiness receipt BLAKE3 `9d1d6ffb9753171adf687216025240994d0d1e68d4118adec62918522dbc7b75`. The executable runbook is 25,195 bytes with BLAKE3 `7b67de5e4bea54a1a55d21e89bbce890eecb2d726af13965bd64859469fb537a`; its executable checker is 15,602 bytes with BLAKE3 `50d3346c140a6f0d13ab5f31c1c5259f16c8bc535768238d2b0bd982e8df2611`. Focused and historical Nix checks, the adversarial runbook self-test, pre-commit `deadnix`/`statix`/`treefmt`, closure audits, and clean detached-worktree Cairn validation/gates passed. Clippy remained unavailable: `/tmp/nix-shell.A8yDpK: line 2373: exec: cargo: not found`.

No software-only check establishes physical execution. A physical run establishes only the exact evidence recorded. It does not establish exact BF16 parity, a wholly device-executed layer/model, general P150 compatibility, serving, throughput, latency, or owner safety when the recovery window is missed.
