## Context

Accepted package `/nix/store/jnn1h441vnxjaqfw35yabvsaznvvq6dg-rwkv-ttwkv7-boundary-device-0.1.0` exposes a fixed `probe` wrapper over ordinary ttWKV7 `/nix/store/5alwcj7ff65s1zg6q475akwayafmh0bz-ttwkv7-unstable-2026-06-22`. Its plan ID is `bdbc6834b6ba3da6e1404858697a01d68d1f58734401d81f4a0f0d2999a5b239`; readiness check `/nix/store/ww8flxsnynczyk7k0s94awyk06mia5a9-rwkv-ttwkv7-boundary-device-check` reports device-free readiness. The wrapper intentionally does not stop or restore the current device owner.

The prior hardware authorization is exhausted. This change creates source artifacts only. The runbook itself is not invoked, its run root is not created, and no command path may initialize a device during validation.

## Success contract

Completion requires an executable argument-free runbook and pure static checker that establish, by exact source inspection:

- immutable package, wrapper, plan, readiness, active-system, owner-control, device-1, service, health, timeout, rollback, and success-marker authorities;
- atomic run-root and execution-lock creation with initial attempt counters fixed at zero and one terminal wrapper-process budget;
- no prompt/file authorization gate, caller argument, retry, fallback, alternate executable, direct ordinary-ttWKV7 invocation, or second wrapper process;
- wrapper `validate-runtime` before isolation and exactly one wrapper `probe` only after rollback is armed, traps are installed, owner service is isolated, container absence and `/dev/tenstorrent/1` owner absence are proven, and board health is captured;
- timeout 900 seconds, TERM then 10-second kill grace, independent rollback at 1,200 seconds, and restoration on EXIT/INT/HUP/TERM;
- complete evidence checks for prepared metadata, 147,456-byte raw writer, 1,536-byte output, 98,304-byte post-state, manifest, receipt, exact workload count, finite passing comparison, and success marker;
- post-restoration service/HTTP/board evidence and a deterministic `rwkv-lab` classification input that cannot claim success when process, artifacts, marker, owner restoration, health, or board health are incomplete;
- a checker self-test that rejects changed device, package, plan ID, invocation duplication/removal, lock/counter removal, isolation/recovery removal, reordered probe, evidence-validation removal, direct runtime invocation, retry, and argument acceptance.

False completion includes executing the runbook, creating its run root, contacting the device, testing only shell syntax, allowing manual threshold or fixture arguments, relying on operator memory for restoration, or describing static validation as physical readiness.

## Functional core and imperative shell

`check-runbook.rs` is a pure deterministic source checker over an in-memory string. Small helpers own exact counts, array membership, and ordering constraints; positive and negative assertions require no mocks. Its thin shell reads one regular source file, checks executable mode, emits one fixed diagnostic, and supports a self-test mode.

`run-one-shot.sh` is the future imperative shell. It owns filesystem evidence, local health calls, service/container state, board-health commands, root loopback SSH for the independent systemd rollback timer, owner-control calls, exact wrapper invocation, timeout, restoration, and evidence materialization. It has no reusable hardware loop.

## Decisions

### Decision: Rebind the accepted prior orchestration pattern

**Choice:** Preserve the prior lock/trap/rollback/isolation/restoration order while replacing the historical data-movement target and artifact schema with the accepted boundary wrapper and plan.

**Rationale:** The pattern already survived a terminal timeout and restored the inference service. Reusing its safety ordering is lower risk than inventing another owner lifecycle.

### Decision: Keep authorization external and execution immutable

**Choice:** The runbook contains no prompt or authorization-file check. It remains unexecuted until a separate explicit operator decision, but once invoked it atomically consumes its single attempt.

**Rationale:** Prompt/file gates are mutable and were removed previously. Attempt accounting and exact plan/package identity are the enforceable local controls.

## Risks / Trade-offs

- **Static checker is mistaken for shell correctness:** run shell syntax checking and exact package/readiness/plan authority checks in addition to adversarial source mutation; still claim source readiness only.
- **Partial process evidence disappears on timeout:** create the run root before invocation, record start/counters, preserve diagnostic logs, and classify incomplete artifacts as non-success after restoration.
- **Rollback timer races the process:** require rollback delay to exceed timeout plus kill grace and leave it armed unless explicit restoration and health checks succeed.
- **Wrapper bypass:** checker rejects direct ordinary ttWKV7 paths and requires exactly two wrapper command sites: device-free preflight and one probe.
- **Rerun after failure:** atomic execution lock and fixed counters make the one process budget terminal.

## Non-claims

This change does not authorize or execute hardware, create runtime/cache/log paths, alter service ownership, establish reader completion, establish numerical P150 correctness, or prove shell behavior under all host failures. It does not establish full-layer/model execution, generation, serving, throughput, or latency.

## Validation evidence

The final argument-free runbook is 20,278 bytes, mode `0755`, with BLAKE3 `52b9ed8b6b6f938ceaf5a097f6bd197938eed1750fcdf420dc9ffb95dca89138`. It pins the accepted boundary package, ordinary package, readiness check, plan ID and hashes, active system, owner-control helper, physical device 1, owner service, wrapper, fixture identity, success marker, 900-second timeout, 10-second kill grace, 1,200-second rollback, exact artifact byte counts, and loopback Inspector/health authorities.

The runbook performs argument rejection, immutable authority checks, atomic run-root creation, zero counters, host-key fingerprint verification, wrapper `validate-runtime`, service/container/health/board preflight, atomic execution lock, EXIT/INT/HUP/TERM restoration traps, rollback arming, owner isolation, container and device-owner absence checks, and exactly one wrapper `probe`. There is no direct `boundary-run`, ordinary ttWKV7 test/bench invocation, retry, fallback, second probe, prompt gate, or authorization file.

Complete evidence requires a four-line manifest, prepared metadata, 147,456-byte writer, 1,536-byte output, 98,304-byte post-state, matching BLAKE3 rows, `device_initialized: true`, fixture authority, `passed: true`, one workload, two finite comparison records, and one exact success marker. The EXIT path records restoration/health/board status, materializes all available plan roles, and invokes `rwkv-lab classify` after recovery; missing or unsafe evidence cannot acquire the success claim.

The Rust checker is 10,613 bytes, mode `0755`, with BLAKE3 `e3552acc335458e8101971f6a1d527cddfa45c98b30524106c86ff9fd1c08e2f`. Positive validation and self-test both report `PASS`. Negative fixtures reject device, package, plan, argument-check, execution-lock, attempt-counter, restoration-counter, trap, rollback, isolation, process-counter, probe removal/duplication, evidence-validation, classification, direct-boundary, and authorization-gate mutations. `bash -n` passes.

Independent no-device authority checks re-hash plan receipt `f67d0ec34a6b67f3a887d1c9c57134d165f6f74fb811b65aecda89068bdd5e89` and readiness receipt `4d63d2a74d6e0e05d5512294bfbd657870f96f0167c60dc2041aacacdd40f09f`, replay the typed plan byte-identically, and confirm initial outcome `not_run`. Full focused formatting passes. Clean detached-worktree Cairn validation and proposal/design/tasks gates report `valid: true`, `verdict: "PASS"`, and no issues.

`/var/tmp/rwkv-ttwkv7-boundary-device-1` remains absent. The runbook was never invoked. No cache, logs, execution lock, owner change, health request, SSH session, `tt-smi`, device file, Metalium initialization, command queue, kernel process, or prior hardware evidence path was accessed.
