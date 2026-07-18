# Design: Isolated persistent response transport

## Success contract

The host must receive every canonical response from a channel that third-party stdout/stderr logging cannot write to accidentally. Completion requires deterministic CPU process-shell and C++ cross-language evidence that deliberate stdout noise is captured separately while the response channel begins at byte zero with `RKW7RSP1`, carries exact frame lengths, preserves 24-call ordering, and fails closed on negative paths. Checks must remain device-free and the historical task-281 evidence must remain immutable.

False completion includes suppressing one known logger configuration, scanning stdout until magic appears, deleting diagnostics, accepting a shortened frame, opening a fresh child per call, changing the canonical response ABI, or running physical hardware.

## Approach registry

| Family | Mechanism | State | Evidence / blocker |
|---|---|---|---|
| Logger configuration | Disable or redirect Metalium logging through version-specific environment or logger APIs | Rejected | Does not isolate unknown UMD/runtime writes and cannot prove stdout exclusivity across dependencies. |
| Stream resynchronization | Scan stdout for `RKW7RSP1` and discard preceding bytes | Rejected | Weakens fail-closed framing and can accept stale, duplicated, or corrupted streams. |
| Inherited descriptor | Clear close-on-exec and pass one inherited response descriptor | Viable but not selected | Isolates output, but requires unsafe host pre-exec descriptor mutation and a new direct libc dependency. |
| Unix response socket | Host binds one private socket; child connects once and writes only canonical responses | Selected | Uses safe Rust standard-library APIs, leaves diagnostics on stdout/stderr, preserves one child, and can be mutation-tested device-free. |

## Functional core and shell

Pure validation functions define socket-path authority, expected diagnostic output, frame sizes, summary authority, and one-connection invariants over in-memory values. The Rust host shell creates the artifact directory and listener, spawns one child, accepts one connection, transfers frames, captures diagnostics, waits, and removes the socket. The CPU fake server and C++ Metalium server each connect once before processing requests. Numerical/model recurrence remains in the accepted pure core.

## Protocol

- Requests remain exact 107,588-byte canonical frames on child stdin.
- Responses remain exact 99,940-byte canonical frames with unchanged ABI and hashes.
- The host creates `<artifact-root>/response.sock` with `UnixListener` and exports its absolute path as `RWKV_TTWKV7_DISPATCH_RESPONSE_SOCKET`.
- Child stdout is a new immutable `server-stdout.log`; stderr remains `server-stderr.log`.
- The child connects exactly once before device initialization. Missing, relative, `/nix/store`, overlong, non-socket, unreachable, or reused paths fail before device work.
- The host accepts one connection, uses it for all responses, and rejects a queued second connection before clean close.
- No code scans diagnostics for response magic.

## Device-free validation

The CPU fake server emits a fixed stdout-noise marker before returning 24 canonical responses through the socket. The process-shell check proves deterministic output, exact transcript authority, separate stdout/stderr artifacts, socket removal, and rejection of truncation, stale responses, early exit, malformed invocation, and extra connection attempts.

A C++ response-channel self-test reads one canonical request from stdin, emits deliberate stdout noise, connects through the production socket helper, and sends the exact deterministic response through the socket. The cross-language Nix check validates byte identity, canonical host decoding, socket cleanup, missing/relative/non-socket path rejection, and argument rejection without device access.

## Audit risks and non-claims

Socket path length, lifecycle cleanup, peer multiplicity, child death, partial writes, `SIGPIPE`, stale filesystem nodes, and diagnostic artifact drift are explicit negative cases. Passing these checks does not establish Metalium logger behavior, device initialization, physical response completion, numerical agreement, recurrent physical continuity, generation, serving, throughput, latency, or permission to execute another hardware attempt.

## Validation evidence

The final device-free package set is:

- ttWKV7: `/nix/store/zx0k9707wbxwm5n1wbmqwxff3dc5wgyk-ttwkv7-unstable-2026-06-22`
- Harness: `/nix/store/8vdazpj6lyay9g8vx346z0ss4bq6ldaz-rwkv-layer-harness-0.1.0`
- Fresh unconsumed session package: `/nix/store/pp97f3b6k13lb22qqh79iy7lnx3ha4qa-rwkv-ttwkv7-persistent-device-0.2.0`
- Process-shell check: `/nix/store/dzb4d0nh7mb9ynimaf9a1bqaxx2rd829-rwkv-ttwkv7-persistent-physical-process-shell`
- Cross-language transport check: `/nix/store/hkhf4zxsp63hzav68dxdyd9xidpkqxmh-rwkv-ttwkv7-persistent-dispatch-transport-check`
- Readiness check: `/nix/store/ahzsp9ihj70b1zhq5izc6nykbq22k8ss-rwkv-ttwkv7-persistent-device-check`

The session is `rwkv-ttwkv7-persistent-device-4` under the absent root `/var/tmp/rwkv-ttwkv7-persistent-device-4`, with plan ID `7c1d1dbc06ba73e5d54f52f929f80aacac52084ad0610a3cce5da60b325df427`. The plan, plan receipt, and not-run receipt BLAKE3 identities are `8261cc89daafa3118ae8da1ea7b46228978f4a1422443ae2c875d83d63791d4d`, `4cfb670fd9c9bc92b9e5d06c5a4adf4439d96b67b44b6de450cb93bf003464fc`, and `f1628fb83aac17fe3c39345f45239b8a5116a9434e6dfe4aa95a3f7eec28b6c7`. The readiness receipt is `de303cd9b69aca918f9573ffc2529b6963f7f27ee961e80e9e8f9c32e0acc46e`.

The dedicated transport, host process shell, readiness, terminal partial-diagnostic evidence, host layout, decode reader, architecture, boundary readiness, and historical persistent/model dispatch checks all pass. The persistent package closure remains 127 paths with exactly one locked Metalium Python path and no PyTorch/Torch framework path; the ordinary harness closure remains 15 paths without Python, PyTorch, or the physical evidence/session roots. Clippy remains unavailable because the evaluated development shell reports `exec: cargo: not found`.
