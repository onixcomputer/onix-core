# Design: Execute the ttWKV7 reader diagnostic

## Goal and Success Evidence

Consume at most one fresh device-1 process to classify the hardened reader boundary. Success requires a committed executable one-shot, exact immutable dependencies, zero-state counters, fresh exact authorization, one diagnostic invocation, complete raw artifacts and records, independent owner restoration, and deterministic terminal classification.

False completion includes model agreement, an uncommitted or mutable runbook, nonzero counters, stale authorization, a wrapper suffix, direct runtime execution, a retry, missing raw capture or argument artifacts, aggregate output without controls, owner restoration without health, or a numerical result generalized beyond this package and process.

## Search Budget and Approach Registry

Use three preparation mechanisms, one adversarial review, and deterministic checks. Stop before owner isolation until exact authorization exists. After authorization, stop after the first outer diagnostic process for every outcome.

| Family | Mechanism | Claim | Evidence | State |
|---|---|---|---|---|
| Immutable dispatch | Pin package, kernels, wrapper target/vector, active system, device, and clean commit | Prevents launch drift | Exact path and wrapper-line checks | active |
| Independent restoration | Arm root-systemd restart before isolation and retain EXIT-trap restoration | Owner recovers from shell/process failure | Timer/service state plus health evidence | active |
| Complete observability | Require thirteen raw captures, twenty-six vectors, thirteen result rows, thirteen log records, and one aggregate marker | One process remains analyzable offline | Manifest/files/log checks and BLAKE3 hashes | active |
| Immediate retry | Correct a failed preparation or output by launching again | Might produce missing evidence | Forbidden by authorization boundary | falsified |

## Reviewed Immutable Inputs

- Base implementation commit: `db012b71eab56d7aa86f1bcf8f5a16f6fc6ec6e9`.
- Package: `/nix/store/l5a5lkkwn7wcp2hvr8c3m5zp4wfyg36y-ttwkv7-unstable-2026-06-22`.
- Kernels: `/nix/store/bag2glrys891mvg2pifn8q4iqjd0qm25-ttwkv7-kernels-unstable-2026-06-22/share/ttwkv7/kernels`.
- Active system and profile: `/nix/store/vb9zjhp20rpg7g1g4ypmmcsq7n4s9d3p-nixos-system-britton-desktop-26.11.20260629.7a1a647`.
- Owner helper: `/nix/store/6m9zwmdfc1vyrxw2znbl39s78bz73ycp-ttwkv7-owner-control/bin/ttwkv7-owner-control`.
- Device visibility: exactly `TT_VISIBLE_DEVICES=1`.
- Run root: `/var/tmp/ttwkv7-reader-diagnostic-20260716T221616Z`.
- Inspector: `127.0.0.1:43136`.
- Required authorization: `Authorize exactly one device-1 reader diagnostic process.`

## Imperative Shell Boundary

The runbook validates all metadata and counters before installing traps or changing owner state. After exact authorization and immutable metadata pass, an atomic persistent execution lock changes the attempt counter from zero to one so concurrent or later re-entry fails even if the diagnostic counter remains zero. It arms a root-systemd rollback timer before isolation, proves the owner and container stopped, proves `/dev/tenstorrent/1` has no owner, increments the invocation counter immediately before one timeout-bounded wrapper command, and never constructs an alternate command. EXIT restoration restarts the prior owner, waits for HTTP 200, disarms rollback only after health, and records terminal board and service evidence.

The package functional core remains the authority for ABI fixtures, exact layout oracles, and mismatch histograms. The runbook only orchestrates immutable I/O and verifies completeness; it does not reinterpret numerical data while the owner is isolated.

## Evidence Contract

A complete process produces these thirteen named records: CB21 loopback, six input uploads, state upload, decode reader, partial chunk reader, full chunk reader, chunked writer, and decode writer. Each name has one raw bf16 file, one producer vector, one consumer vector, and one manifest result row. The log has one matching case record and exactly one aggregate marker.

After restoration, raw artifacts, vectors, manifest, diagnostic log, statuses, and owner evidence receive BLAKE3 hashes. Classification follows the accepted decision table:

- failed capture control: `capture-infrastructure-invalid`;
- failed input control: `input-packing-suspected`;
- failed state control: `state-packing-suspected`;
- controls pass and decode fails: `decode-reader-suspected`;
- partial chunk fails while full chunk passes: `chunk-tail-fill-suspected`;
- both readers fail after controls pass: `shared-reader-gather-suspected`;
- both readers and writers pass: `validated-reviewed-data-movement-boundary`;
- invalid vector, missing artifact/record, process/infrastructure failure, or unhealthy restoration: `partial-diagnostic`.

## Offline Validation and Adversarial Audit

The immutable package self-test passes and its public wrapper rejects the unreviewed artifact-self-test suffix. Package `/nix/store/l5a5lkkwn7wcp2hvr8c3m5zp4wfyg36y-ttwkv7-unstable-2026-06-22`, package check, architecture check `/nix/store/2fpka4z9wfi4z5r4pkjdi00mpva6bpzl-ttwkv7-architecture-check`, and host closure `/nix/store/xvwgivlwb6jymrfk55jbba2ah2n2gjmd-nixos-system-britton-desktop-26.11.20260629.7a1a647` build without device access. Bash syntax, ShellCheck, treefmt, runbook checker self-tests, Cairn validation/gates, and pre-commit pass.

The adversarial pass found a concurrent re-entry gap: separate processes could both observe zero counters before either incremented the invocation count. The runbook now atomically creates a persistent execution lock after exact authorization and immutable metadata validation but before traps, privilege, owner, or device operations. Positive and negative checker fixtures require that lock and reject device/auth changes, counter removal, duplicate diagnostic commands, and evidence-validator removal. The suggested extra-log concern is already excluded by requiring exactly thirteen total `case=` lines plus each exact pattern once. The suggested rollback concern is already excluded because failed restoration or health deliberately leaves the independent timer armed.

## Authorization Boundary

Preparation may create and validate repository and filesystem metadata but MUST NOT enumerate, initialize, open, stop, or communicate with a Tenstorrent device. The runbook cannot pass its authorization check unless the exact required sentence is recorded from the user. Acquiring the persistent execution lock consumes the sole attempt; any subsequent preparation, launch-path, initialization, process, or evidence failure is terminal. This change cannot authorize a second process.
