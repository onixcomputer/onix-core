# Design: Validate ttWKV7 Blackhole reader gather alignment

## Goal and Success Evidence

Use at most one fresh device-1 process to determine whether the aligned-scratch patch makes all three production-reader records exact while retaining passing controls and writers. Success requires thirteen complete records, status zero, exact reader ABI vectors, raw artifacts before interpretation, healthy independent restoration, and one aggregate PASS marker.

A missing record, nonzero mismatch/status, infrastructure failure, stale package, mutable command, unhealthy restoration, retry, or inference beyond the reviewed package/process is false completion and terminal.

## Reviewed Boundary

- Base commit: `7cc34589484579a408e358852428fe0e3f681f6d`.
- Package: `/nix/store/4d6syhgiq81md3m9np6j39qdaa6rl8rj-ttwkv7-unstable-2026-06-22`.
- Kernels: `/nix/store/fda5gkrr1klpk5ha49yih1myk5sni78p-ttwkv7-kernels-unstable-2026-06-22/share/ttwkv7/kernels`.
- Architecture check: `/nix/store/d65lsbfrkrzmxn4877z2d2060ggazrqb-ttwkv7-architecture-check`.
- Active system/profile: `/nix/store/vb9zjhp20rpg7g1g4ypmmcsq7n4s9d3p-nixos-system-britton-desktop-26.11.20260629.7a1a647`.
- Device visibility: exactly `TT_VISIBLE_DEVICES=1`.
- Run root: `/var/tmp/ttwkv7-aligned-reader-validation-20260716T232813Z`.
- Inspector: `127.0.0.1:43137`.
- Required authorization: `Authorize exactly one device-1 aligned-reader validation process.`

## Offline Validation Evidence

The corrected package oracle, package check, dual-architecture reader/peer compilation, Bash syntax, ShellCheck, treefmt, runbook positive/negative self-test, Cairn validation/gates, and host closure `/nix/store/fl7rgvj9sarvi9p35r6pqzilldrh0q5s-nixos-system-britton-desktop-26.11.20260629.7a1a647` pass without device access. The source checker binds the new package, kernel closure, authorization sentence, port, run root, atomic attempt lock, exact command count, record cardinality, and ordering.

## One-Shot Contract

The reviewed runbook inherits the validated atomic attempt lock, exact wrapper/source checks, strict trust, root-systemd rollback, owner isolation proof, timeout, thirteen-record completeness validator, and EXIT restoration. It changes only the immutable implementation paths, run identity, port, and authorization scope.

The process repeats CB21 loopback, six full input uploads, complete state upload, decode-L1, chunked partial, chunked full, and both writers. This direct A/B comparison changes the reader gather implementation while retaining shape, tags, vectors, capture path, and decision rules.

## Decision Table

- Every control, reader, and writer exact with status zero: `validated-aligned-reader-data-movement`.
- Controls pass but any reader fails: `reader-alignment-fix-incomplete` with exact histograms.
- Any control, artifact, ABI, process, orchestration, or restoration failure: `partial-diagnostic`.

No result validates WKV arithmetic or performance. Another process requires another fresh lifecycle and authorization.
