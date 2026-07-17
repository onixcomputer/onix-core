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
- Launch gate: immutable metadata and zero-state checks; no prompt authorization artifact.

## Offline Validation Evidence

The corrected package oracle, package check, dual-architecture reader/peer compilation, Bash syntax, ShellCheck, treefmt, runbook positive/negative self-test, Cairn validation/gates, and host closure `/nix/store/fl7rgvj9sarvi9p35r6pqzilldrh0q5s-nixos-system-britton-desktop-26.11.20260629.7a1a647` pass without device access. The source checker binds the new package, kernel closure, port, run root, atomic attempt lock, exact command count, record cardinality, and ordering while rejecting a reintroduced prompt-authorization gate.

Run root `/var/tmp/ttwkv7-aligned-reader-validation-20260716T232813Z` is mode 0700 with isolated writable roots, strict fingerprint `SHA256:0vd1vzTWrAONyquNKjwnsGY7a5bY2NJlvFamtxy/akY`, free port 43137, an absent attempt lock, and all counters zero. Preparation does not launch the runbook or contact a device; the owner remains healthy.

## One-Shot Contract

The reviewed runbook inherits the validated atomic attempt lock, exact wrapper/source checks, strict trust, root-systemd rollback, owner isolation proof, timeout, thirteen-record completeness validator, and EXIT restoration. It requires no prompt authorization sentence or file.

The process repeats CB21 loopback, six full input uploads, complete state upload, decode-L1, chunked partial, chunked full, and both writers. This direct A/B comparison changes the reader gather implementation while retaining shape, tags, vectors, capture path, and decision rules.

## Decision Table

- Every control, reader, and writer exact with status zero: `validated-aligned-reader-data-movement`.
- Controls pass but any reader fails: `reader-alignment-fix-incomplete` with exact histograms.
- Any control, artifact, ABI, process, orchestration, or restoration failure: `partial-diagnostic`.

No result validates WKV arithmetic or performance. Another process requires another fresh reviewed lifecycle and zero-state boundary.

## Terminal Physical Evidence

The clean detached checkout at commit `492ba141e2ab5e92b2dfdac3470409ac69ada35d` directly launched the runbook once. The atomic attempt, invocation, service-stop, and rollback-arm counters are each one. The sole diagnostic returned timeout status 124 after 600 seconds, and the completeness validator returned one; no retry, fallback, suffix, alternate command, or direct-runtime process ran.

CB21 loopback, all six full input uploads, and the complete state upload produced eight raw captures, sixteen runtime vectors, and eight exact PASS rows. Inspector records show the matching control programs completed and were destroyed. The next program compiled `wkv7_decodeL_reader`, committed the decode-L1 workload, and never produced a workload-destroyed record, capture, vector pair, or result before timeout. The chunked readers and both writer cases were not reached. This is terminal `partial-diagnostic`: the aligned-reader package preserves every control but does not establish that the first production reader completes or is correct.

The initial restore command returned success, but health did not recover within the runbook window. The first owner restart then failed while starting device 1 because a 4-byte MMIO load took 220,644 microseconds against a 10-millisecond budget. At least two owner restart attempts failed, a third began, and the prior journal ended abruptly at 20:29:40 without a clean shutdown sequence. The next boot began at 21:04; the evidence establishes a hard boot boundary but not its cause. Because the runbook did not reach final restoration, it left the independent rollback armed as designed.

After reboot, `tt-smi` passed. Boot activation had stopped on an unrelated undecryptable Mesh-LLM secret, so the exact SOPS-encrypted Clan owner credential was restored to its declared root-only runtime path and the original owner unit was started. The owner is now active/running with `Result=success`, `NRestarts=0`, and HTTP 200. Two final board samples pass with advancing heartbeats, `DDR_STATUS=0x5555`, zero uncorrectable GDDR errors, and zero thermal trips on both cards.

Evidence remains at `/var/tmp/ttwkv7-aligned-reader-validation-20260716T232813Z`. The pre-manifest run-root hash is `blake3-dvZqXdg6X+90qyDxffhbdJQ1gQ4B1+LoXFeYwovhS6c=`, partial artifact-tree hash is `blake3-VqXe77pXCBPJFRbdk/d/SCg7+2/CkyNFS024Cw919i8=`, Inspector-tree hash is `blake3-e/lUSN6iCLOtlXMWvTQMeyBWuJF329ZhsuZypmTKVsM=`, diagnostic-log hash is `blake3-mBhAincX7ntunCvbAPHvKI1sVtsngENOHYTBo9rsDvo=`, and classification hash is `blake3-Y3zjs1fzd1Zy1tzTUf7IR3Mtfwjc4Q4+yQyrXXSgRq4=`.
