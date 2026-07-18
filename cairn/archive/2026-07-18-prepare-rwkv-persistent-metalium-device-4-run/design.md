# Design: Persistent Metalium device-4 run boundary

## Authorities

The runbook will bind session `rwkv-ttwkv7-persistent-device-4`, fresh root `/var/tmp/rwkv-ttwkv7-persistent-device-4`, physical device `1`, Inspector `127.0.0.1:43158`, and owner `docker-tt-inference-server-llama-3-1-8b-instruct-p150.service`.

Immutable package authority:

- Session package: `/nix/store/pp97f3b6k13lb22qqh79iy7lnx3ha4qa-rwkv-ttwkv7-persistent-device-0.2.0`
- Readiness check: `/nix/store/ahzsp9ihj70b1zhq5izc6nykbq22k8ss-rwkv-ttwkv7-persistent-device-check`
- ttWKV7 package: `/nix/store/zx0k9707wbxwm5n1wbmqwxff3dc5wgyk-ttwkv7-unstable-2026-06-22`
- Harness package: `/nix/store/8vdazpj6lyay9g8vx346z0ss4bq6ldaz-rwkv-layer-harness-0.1.0`
- Plan ID: `7c1d1dbc06ba73e5d54f52f929f80aacac52084ad0610a3cce5da60b325df427`
- Manifest/plan/not-run BLAKE3: `8261cc89daafa3118ae8da1ea7b46228978f4a1422443ae2c875d83d63791d4d`, `4cfb670fd9c9bc92b9e5d06c5a4adf4439d96b67b44b6de450cb93bf003464fc`, and `f1628fb83aac17fe3c39345f45239b8a5116a9434e6dfe4aa95a3f7eec28b6c7`
- Readiness receipt BLAKE3: `de303cd9b69aca918f9573ffc2529b6963f7f27ee961e80e9e8f9c32e0acc46e`

The active system remains `/nix/store/vb9zjhp20rpg7g1g4ypmmcsq7n4s9d3p-nixos-system-britton-desktop-26.11.20260629.7a1a647`; the reviewed loopback Ed25519 fingerprint is `SHA256:DOOddCNRRRqCVbueQZovbR8Q//NwYeeMCaznz+GqxQE`.

## Lifecycle

The argument-free runbook atomically creates the fresh root and consumes its one invocation lock. Restoration traps are installed immediately. It validates immutable authority before owner isolation, arms an independent 2,100-second rollback timer, stops the owner exactly once, runs one 1,800-second process with a 10-second kill grace, validates all evidence, restores ownership, waits up to the complete 600-second health window, disarms rollback only after restoration evidence, and emits one terminal `rwkv-lab` classification.

No retry, reconnect, fallback, direct runtime substitution, second process, or reinterpretation is allowed. A timeout or interruption is terminal. A physical/numerical success cannot override unsafe owner or board evidence, and later health cannot upgrade a missed restoration window.

## Artifact contract

The physical host manifest has exactly seven lines: one header and six rows for `receipt.json`, `core-receipt.json`, `server-summary.json`, `transcript.bin`, `server-stdout.log`, and `server-stderr.log`. Every row binds role, filename, exact bytes, and BLAKE3. The validator requires:

- exactly 24 physical calls, workloads, request hashes, and response hashes;
- exactly 12 same-layer continuity links;
- one host process, one Metalium child, one device open, and one Unix response connection;
- zero retries and reconnects;
- canonical response frames beginning at byte zero on the response channel;
- separate stdout/stderr artifacts, exact transcript size, clean close, finite complete vectors, numerical ceilings, and retained/oracle ranking agreement;
- exact success marker only on a complete safe path.

Logger text in `server-stdout.log` is diagnostic evidence and is never parsed as protocol. The response socket itself must be removed and cannot appear as a residual artifact after process exit.

## Checker and mutations

The Rust checker validates an exact runbook/checker pair and self-tests mutated package paths, hashes, session/root/device/port, process and timeout budgets, health window, rollback unit, service, host key, manifest rows, stdout role, response connection, call/continuity counts, success marker, missing restoration traps, retry/reconnect text, suffix arguments, and historical-root reuse. Its self-test uses temporary fixtures only and cannot create the declared run root or execute commands from the runbook.

## Non-claims

Archiving this boundary does not authorize execution and does not establish a second physical response, numerical parity, cross-token physical continuity, 24 physical calls, a full device layer/model, generation, serving, throughput, latency, or general P150 compatibility.

## Validation evidence

The 27,866-byte runbook is mode `0755` with BLAKE3 `9f4dac687763712ecf527707673bf1502b3a9ab53b77e365963f8dea7864998f`. The 17,351-byte checker is mode `0755` with BLAKE3 `39d914c48447f1f8205a3c16fd8ae5141ac295a91c8e1838ec7b4ddc2bdb452e`. Direct syntax, ShellCheck, checker, and mutation self-test pass.

The dedicated Nix check is `/nix/store/ig1md8dizfza22qxb4ybk9jwkpc6jj6f-rwkv-ttwkv7-persistent-device-4-runbook-check`; its receipt BLAKE3 is `92a66210559590523f7dc8b6154bbbf94af6221627bcc2136516afb74cb35e69`. It compiles the pure checker with `rustc`, replays positive and negative fixtures, runs `bash -n` and ShellCheck, and records `device_initialized: false` and `hardware_process_started: false`.

The runbook, readiness, process-shell, cross-language transport, terminal partial-diagnostic, and historical boundary checks pass together. The declared runtime root remains absent, and no physical or owner-service process occurred during preparation.
