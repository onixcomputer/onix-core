# Proposal: Isolate RWKV persistent response transport

## Why

The sole physical persistent-session attempt completed one Metalium workload, but the host rejected response zero because Metalium logger text preceded canonical `RKW7RSP1` bytes on child stdout. Stdout is therefore not an exclusive binary channel and cannot safely carry physical responses.

## What changes

- Move production response frames from stdout to one dedicated Unix-domain stream created by the host and connected once by the persistent child before device initialization.
- Keep stdin as the request stream and capture child stdout and stderr as diagnostic artifacts only.
- Exercise the same channel with deliberate stdout noise in the CPU fake server and a device-free C++ cross-language fixture.
- Reject missing, malformed, stale, duplicate-connection, truncated, and protocol-contaminated channel behavior without scanning for magic or accepting partial frames.
- Refresh immutable package/readiness authority device-free without creating a runbook or authorizing hardware.

## Boundary

This change repairs and validates process transport only. It does not rerun task `281`, open a device, execute a kernel, establish physical numerical parity or recurrent continuity, or authorize another hardware process.
