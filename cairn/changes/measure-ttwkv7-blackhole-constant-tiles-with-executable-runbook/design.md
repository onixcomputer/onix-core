## Context

The immediately preceding change exhausted its orchestration boundary at shell status 126 because the committed runbook lacked executable mode. Invocation count, service-stop attempts, and rollback-arm attempts remained zero, so no mask evidence exists. The new runbook is created with mode `0755` rather than repairing or rerunning the archived artifact.

The exact package is `/nix/store/plr5vlpv1q5g4zl6c2q065bwsmbhxkrr-ttwkv7-unstable-2026-06-22`, immutable kernels resolve to `/nix/store/8m898sjjhcvva2l8375r1wi5alp6cmj3-ttwkv7-kernels-unstable-2026-06-22/share/ttwkv7/kernels`, and owner control is `/nix/store/6m9zwmdfc1vyrxw2znbl39s78bz73ycp-ttwkv7-owner-control/bin/ttwkv7-owner-control`.

## Success Contract

Validated success requires exactly fourteen `mismatches=0 PASS` records—seven patterns at lengths 1 and 32—plus `constant-tile device probe: PASS` and process status zero from one invocation. Preflight, launchability, initialization, JIT, partial passes, plausible values, restoration, or status zero without the records are false completion.

Allowed outcomes are `validated`, `mask-mismatch`, `initialization-blocked`, `timed-out`, `isolation-blocked`, or `orchestration-blocked`. The first terminal result ends this change without retry.

## Authorization Boundary

After being told that a new executable runbook, Cairn change, and explicit authorization were required, the user instructed `do it`. This authorizes exactly one new device-1 `probe` process after all offline and runtime preconditions pass. It does not authorize rerunning the archived command, invoking through `bash`, a second process, a fallback command, full-WKV execution, source mutation, deployment, or another device.

The attempt is bound to base commit `75212551c13375126fd2f00b4ba82286540ccd23`, active closure `/nix/store/vb9zjhp20rpg7g1g4ypmmcsq7n4s9d3p-nixos-system-britton-desktop-26.11.20260629.7a1a647`, evidence root `/var/tmp/ttwkv7-constant-probe-20260716T175053Z`, Inspector `127.0.0.1:43129`, device 1, owner `docker-tt-inference-server-llama-3-1-8b-instruct-p150.service`, and one 180-second timeout with 10-second kill grace.

## Decisions

### Prove launchability twice

Before commit, the runbook must be executable. After the final preflight commit, validation requires `test -x`, filesystem mode `0755`, Git index/tree mode `100755`, a successful direct negative extra-argument invocation, and a clean worktree. The physical command uses the direct committed path exactly once.

### Preserve independent restoration

Strict fingerprint-pinned loopback root SSH arms a fixed root-systemd timer for the exact owner start before isolation. The exit trap restores immediately through the least-privilege helper and disarms the timer only after endpoint recovery.

### Count only the physical process

The retained count changes from zero to one immediately before the sole timeout-wrapped `probe` command. Any process status, signal, timeout, initialization failure, or numerical output consumes authorization.

## Approach Registry

| Family | Mechanism | Evidence | State |
|---|---|---|---|
| Direct executable runbook | Commit mode `100755` and invoke the reviewed path | Filesystem, index, tree, and direct negative execution checks | selected |
| Bash interpreter fallback | Run a non-executable file via `bash` | Would bypass the reviewed launch boundary | rejected |
| Post-failure chmod and rerun | Repair an exhausted artifact | Violates no-retry and changes reviewed evidence | rejected |
| Helper-only restoration | EXIT trap restores ordinary exits | Activated helper validates | active but insufficient alone |
| Root-systemd fallback | Timed exact owner start survives client loss | Rehearsed strict root channel and timer semantics | selected |
| Exact mask comparison | Compare every BF16 zero/one element | Offline oracle and architecture gates pass; hardware output unknown | independent |

## Adversarial Audit

Offline success must fail if mode is not executable, Git mode is not `100755`, worktree metadata differs, invocation count is nonzero, Inspector is busy, owner/helper/root channel is unhealthy, timer cannot arm, isolation is incomplete, or device ownership remains. Static review requires one literal probe boundary and no probe retry loop. Post-run classification requires fourteen unique pattern/length records plus the final marker; duplicate or missing lines cannot pass.

## Search Budget

Offline work is bounded to lifecycle, package, architecture, launchability, timer, metadata, and no-device runtime checks. Physical search is one process on device 1 under one 180-second timeout. Any exact terminal boundary ends the change.
