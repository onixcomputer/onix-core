# Proposal: Prepare persistent Metalium device-4 run boundary

## Why

The task-281 physical session proved one workload commit but failed because Metalium diagnostics shared stdout with binary responses. The accepted response-channel repair now isolates protocol bytes and provides a fresh, device-free `not_run` package for session `rwkv-ttwkv7-persistent-device-4`. A new recoverable run boundary is required before any later hardware authorization can be interpreted safely.

## What changes

- Bind the exact device-4 package, plan, readiness receipt, active system, loopback host key, owner service, process budget, timeout, rollback, and evidence schema into one argument-free runbook.
- Validate the new six-artifact host manifest plus its header, including separate `server-stdout.log` and `server-stderr.log` evidence.
- Preserve one process, one persistent child, one response connection, one MeshDevice, 24 calls, 12 continuity links, zero retries/reconnects, and fail-closed numerical/model checks.
- Add an adversarial checker and device-free mutation self-test covering authority, invocation, artifact, health, restoration, and transport drift.
- Commit and archive the immutable runbook without creating its runtime root or invoking hardware.

## Boundary

This change prepares evidence and recovery authority only. It does not authorize or execute a hardware process, reuse tasks `30`, `64`, or `281`, alter their terminal receipts, inspect a board, stop the owner service, open a device, or run a kernel.
