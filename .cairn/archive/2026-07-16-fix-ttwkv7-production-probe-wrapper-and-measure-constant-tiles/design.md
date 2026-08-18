## Context

The exact package `/nix/store/plr5vlpv1q5g4zl6c2q065bwsmbhxkrr-ttwkv7-unstable-2026-06-22` passed its install checks, but its production probe wrapper contains `exec $out/libexec/ttwkv7/wkv7-constant-probe-runtime "$@"`. During the exhausted attempt, inherited `out=/home/brittonr/git/onix-core/outputs/out` redirected dispatch outside the package and produced status 127. The runtime binary never started and no device was opened by ttWKV7.

The owner is again active and healthy on device 1. This change treats the user's `do it` as authorization for one fresh physical process only after the wrapper repair and every device-free gate pass. Any process result exhausts that authorization.

## Success Contract

Validated success requires process status zero, exactly fourteen unique records covering seven patterns at lengths 1 and 32 with `mismatches=0 PASS`, and the final `constant-tile device probe: PASS` marker. Package-build success, fake-wrapper success, runtime initialization alone, partial comparisons, model agreement, or owner restoration alone are not mask success.

The run is terminal as validated, mask-mismatch, initialization-blocked, signaled, timed-out, or orchestration-blocked. Every terminal result restores ownership and forbids a retry or alternate launch command in this change.

## Decisions

### Decision: Expand the runtime target during the package build

**Choice:** Keep runtime-state validation in `probe-wrapper.sh`, quote its executable placeholder, and replace that placeholder with the shell-expanded derivation output path while constructing the composed package.

**Rationale:** The generated wrapper then contains one immutable absolute Nix-store path and does not depend on the caller's `out` environment. This is smaller and more auditable than runtime path discovery and preserves the existing wrapped runtime environment.

### Decision: Test the production wrapper, not only a fake target

**Choice:** Package validation SHALL inspect the actual composed wrapper target, prove it exists and is executable, reject an unexpanded `$out` target, and run the actual no-device `self-test` with `out` both absent and hostile.

**Rationale:** The previous fake target proved forwarding logic but could not detect composition failure. The C++ `self-test` returns before device creation, so it safely proves production dispatch.

### Decision: Preserve the one-shot physical boundary

**Choice:** Use a fresh committed mode-100755 runbook with a unique mode-0700 evidence root, unused loopback Inspector port, exact package/kernel/helper paths, a root-systemd rollback timer armed before isolation, ordinary exit-trap restoration, one 180-second timeout with 10-second kill grace, and invocation count transition immediately before the process.

**Rationale:** Wrapper repair does not justify broader device authority or retries. Independent restoration protects the owner if orchestration terminates unexpectedly.

## Portfolio Registry

| Family | Mechanism | Claim | Artifact / discriminating check | State |
|---|---|---|---|---|
| build-expanded-target | Substitute the current derivation output path while building the wrapper | Dispatch is immutable and independent of runtime `out` | Actual wrapper contains an executable `/nix/store/.../libexec/...` target; `env -u out` and hostile `out` self-tests pass | active |
| runtime-relative-target | Resolve a sibling path from `$0` at runtime | Dispatch remains package-relative | Would require path canonicalization and symlink semantics in the imperative wrapper | rejected as unnecessary hidden runtime logic |
| merged-wrapper | Remove the outer safety wrapper and fold checks into generated `makeWrapper` output | One wrapper avoids target substitution | Risks bypassing explicit runtime-state validation and increases generated-wrapper coupling | rejected |

The surviving candidate is accepted only after adversarial checks demonstrate no literal runtime `$out`, no fake-only evidence, no behavior change under hostile `out`, exact target executability, and unchanged device-free negative behavior.

## Device-Free Validation Evidence

The baseline exact package passed its existing install checks while its production wrapper failed the actual no-device self-test with status 1 when `out` was absent and status 127 when `out` was hostile. The repaired package is `/nix/store/ibrza5pk4sazc4w6yrjrikczghw4w54y-ttwkv7-unstable-2026-06-22`. Its generated wrapper embeds the exact executable runtime target under that output, contains no runtime `$out` dispatch, and reaches the pinned self-test with `out` absent and hostile.

Package install checks, Bash syntax, ShellCheck, tree formatting, `git diff --check`, Blackhole/Wormhole architecture check `/nix/store/gd9vxrlmf8i2lqpz9x13czypijcmhbj0-ttwkv7-architecture-check`, and complete host closure `/nix/store/f5q38n9yla7w8s63kgr19ri6ln8p93qq-nixos-system-britton-desktop-26.11.20260629.7a1a647` pass. The active system remains the prior reviewed closure; exact-store probe execution does not require activation. A focused secondary review returned no concrete defect, and manual audit confirmed the C++ self-test returns before `MeshDevice::create_unit_mesh`.

## Physical Preflight Evidence

The executable runbook is committed with filesystem mode `0755` and Git mode `100755`; direct negative execution reaches its argument guard. Its static boundary contains one invocation-count transition and one direct `probe` process under the reviewed timeout, with rollback arming before owner isolation and no retry path.

A fresh root-systemd timer rehearsal armed, proved active, stopped, and disappeared without service mutation. Evidence root `/var/tmp/ttwkv7-constant-probe-20260716T182116Z` is mode 0700 and binds repaired package `/nix/store/ibrza5pk4sazc4w6yrjrikczghw4w54y-ttwkv7-unstable-2026-06-22`, unchanged kernel output, active closure, owner-control helper, device 1, Inspector `127.0.0.1:43130`, strict loopback SSH fingerprint, and explicit authorization. The actual production target and hostile-environment self-tests pass, runtime-state preflight passes, the port is unused, the owner is active with HTTP 200, and invocation, service-stop, and rollback-arm counts are zero.

## Measured Outcome

The immutable-target repair worked: the committed runbook reached the exact store wrapper once after rollback arming, owner isolation, inactive-container proof, and exact device-ownership proof. Invocation count changed from zero to one immediately before the sole process.

The process returned status 2 before device open. In the production wrapper's `probe)` branch, line 78 shifts away `probe`; line 81 then executes the correct immutable runtime target with only `"$@"`. Because this authorized invocation had no additional arguments, the C++ binary received no mode, printed `usage: ... self-test|probe`, and returned before `MeshDevice::create_unit_mesh`.

The device-free checks exposed a second false-completion path. Hostile-`out` self-tests use the wrapper's default branch and therefore do not exercise probe-mode dispatch. The fake probe test asserted only that an additional argument survived the shift, not that the required `probe` mode was restored. The focused secondary review and manual target audit also missed this semantic argument loss.

The exit trap restored the owner with status 0, endpoint health recovered to HTTP 200, and rollback disarm returned 0. The timer and service units are not found/inactive. The owner is active/running with `Result=success` and `NRestarts=0`; both boards retain healthy DRAM, zero uncorrectable GDDR errors, zero thermal trips, and advancing heartbeats.

This is the exact `probe-mode-dispatch-blocked-before-device-open` terminal result. Invocation count is one, so no argument repair, direct runtime-binary fallback, alternate command, or retry is authorized. All fourteen masks remain unmeasured. Evidence is retained at `/var/tmp/ttwkv7-constant-probe-20260716T182116Z`.

## Risks / Trade-offs

- A no-device self-test could accidentally become device-owning upstream. The pinned source is inspected and package behavior remains bound to the fixed revision; physical authorization is not inferred from package tests.
- A correct wrapper may reveal a later Metalium initialization or mask defect. That is a valid terminal result, not permission to retry.
- Owner restart may take time after isolation. The runbook retains bounded health polling, independent rollback, service properties, endpoint state, container state, and two board snapshots.
- The pre-existing full-WKV numerical failure remains out of scope and cannot be reclassified by constant-mask success.

## Search Budget

The repair search used three mechanism families, one secondary review, focused source inspection, and deterministic package/architecture/closure checks. The exact immutable-target candidate survived those checks but was falsified as a complete probe-dispatch repair by the missing mode argument. The single physical process returned status 2 before device open and exhausted the search without retry.
