## Context

Package `/nix/store/ibrza5pk4sazc4w6yrjrikczghw4w54y-ttwkv7-unstable-2026-06-22` embeds the correct immutable runtime target. Its `probe)` branch then executes `shift`, validates runtime state, and dispatches only `"$@"`. With no forwarded arguments, the pinned C++ binary receives no mode, prints usage, and returns before `MeshDevice::create_unit_mesh`.

The owner is active and healthy on device 1. The user's `do it` authorizes one fresh physical process only after this semantic dispatch repair and all device-free gates pass. Every process result exhausts that authorization.

## Success Contract

Validated measurement requires process status zero, exactly fourteen unique `mismatches=0 PASS` records covering seven patterns at lengths 1 and 32, and `constant-tile device probe: PASS`. Package success, fake-wrapper success without exact argument assertions, runtime initialization, partial comparisons, model approval, or restoration alone are false completion.

Allowed terminal outcomes are validated, mask-mismatch, initialization-blocked, signaled, timed-out, or orchestration-blocked. Every terminal result restores ownership and forbids fallback or retry within this change.

## Decisions

### Decision: Reinsert the validated mode explicitly

**Choice:** After consuming `probe` for wrapper dispatch and validating runtime state, execute the immutable target with literal `probe` followed by the untouched forwarded arguments.

**Rationale:** The generated production line becomes directly inspectable, while the fixed literal makes the wrapper-to-binary contract explicit. It changes only the broken branch and preserves the validated runtime-state shell.

### Decision: Assert the whole argument vector

**Choice:** Execute the wrapper against a fake no-device target first with no forwarded argument and then with one sentinel. Require exact outputs `probe` and `probe` followed by the sentinel, respectively. Also inspect the actual generated production branch for its immutable target plus literal mode.

**Rationale:** Exact-vector equality rejects dropped, duplicated, and reordered modes. Production-target inspection plus actual no-device self-tests prevents fake-only validation from standing alone.

### Decision: Preserve the prior one-shot controls

**Choice:** Commit a fresh mode-100755 runbook with a unique mode-0700 evidence root, unused loopback Inspector port, exact package/kernel/helper paths, independent root-systemd rollback before isolation, ordinary exit-trap restoration, one 180-second timeout with 10-second kill grace, and count transition immediately before one process.

**Rationale:** A semantic argument repair does not authorize broader privilege, direct-binary fallback, or retries.

## Portfolio Registry

| Family | Mechanism | Claim | Discriminating check | State |
|---|---|---|---|---|
| explicit-mode-reinsertion | Dispatch immutable target as `probe "$@"` after validation | Required mode and forwarded suffix are exact | Generated production line plus fake-target exact vectors for zero and one suffix argument | active |
| preserve-original-vector | Do not shift and dispatch original `"$@"` | No argument transformation occurs | Fake exact-vector test | viable but rejected because branch contract is less explicit |
| mutable-array-rebuild | Copy and reconstruct positional arguments in an array | Explicit transform can be extended | Array equality tests | rejected as unnecessary mutation and complexity |

The surviving candidate is accepted only if actual production target inspection, exact fake vectors, hostile-`out` self-tests, runtime-state negatives, package builds, architecture compilation, and host closure all pass.

## Device-Free Validation Evidence

The baseline package passed while lacking any production `exec ... probe "$@"` line. Repaired package `/nix/store/3f485zv9vz38rd8048bwc7qkshg2m5cl-ttwkv7-unstable-2026-06-22` embeds the exact immutable target plus literal mode. Its install check executes exact fake vectors with zero and one suffix arguments, and its actual pinned self-test passes with caller `out` absent and hostile.

Package checks, Bash syntax, ShellCheck, tree formatting, `git diff --check`, deadnix, statix, architecture check `/nix/store/gd9vxrlmf8i2lqpz9x13czypijcmhbj0-ttwkv7-architecture-check`, and host closure `/nix/store/7jk56nhwls296i386jbgaih23z4a61xj-nixos-system-britton-desktop-26.11.20260629.7a1a647` pass. Because pre-commit's treefmt wrapper cannot discover `.git/config` inside a linked worktree, the exact repair commit was first fast-forwarded to the primary checkout; `pre-commit run --all-files` then passed deadnix, statix, and treefmt while preserving unrelated user changes.

A secondary review endpoint initially failed, then returned five proposed defects. Manual discriminating checks falsified each: literal `probe` remains when the suffix is empty; the default branch is irrelevant to `probe)` dispatch; the fake target's quoted `printf` preserves argv order; the actual pinned self-test is independent of fake output; and complete-output equality rejects reordering. The deterministic package checks, not model approval, remain authoritative.

## Physical Preflight Evidence

The fresh runbook is committed with filesystem mode `0755` and Git mode `100755`; direct negative execution reaches its argument guard. Static review finds one count transition and one direct outer-wrapper `probe` process. The runbook requires the actual production line containing the immutable target plus literal mode before owner or device action.

A disposable root-systemd timer rehearsal armed, proved active, stopped, and disappeared without service mutation. Evidence root `/var/tmp/ttwkv7-constant-probe-20260716T185657Z` is mode 0700 and binds repaired package `/nix/store/3f485zv9vz38rd8048bwc7qkshg2m5cl-ttwkv7-unstable-2026-06-22`, unchanged kernels, active closure, owner-control helper, device 1, Inspector `127.0.0.1:43131`, strict loopback SSH fingerprint, and explicit authorization. Production dispatch and hostile-environment self-tests pass, runtime-state preflight passes, the port is unused, the owner is active with HTTP 200, and invocation, service-stop, and rollback-arm counts are zero.

## Measured Outcome

The committed runbook armed and proved the independent rollback timer, isolated the prior owner, proved its container inactive and device 1 without an open owner, then changed invocation count from zero to one immediately before the sole process.

The exact package opened selected Blackhole device 1 and returned status zero. Evidence contains exactly one record for every combination of seven reviewed patterns and lengths 1 and 32; all fourteen records report `mismatches=0 PASS`, and the log contains exactly one `constant-tile device probe: PASS` marker. The classifier rejects missing, duplicate, extra-pattern, wrong-length, nonzero-mismatch, absent-marker, or nonzero-status outcomes.

Metalium emitted non-fatal environmental warnings: power-state setting returned invalid argument, firmware capability selected compatible single-erisc fallback, optional fabric mapping exports targeted a read-only store path, and shared-memory statistics creation was denied. These warnings did not prevent JIT execution, exact tile comparisons, status zero, or orderly device close; they are not generalized away from this exact run.

The exit trap restored the owner with status 0, endpoint health recovered to HTTP 200, and rollback disarm returned 0. The rollback units are not found/inactive. The owner is active/running with `Result=success` and `NRestarts=0`; both boards retain healthy DRAM, zero uncorrectable GDDR errors, zero thermal trips, and advancing heartbeats.

Outcome is `validated-exact-constant-tiles` for package `/nix/store/3f485zv9vz38rd8048bwc7qkshg2m5cl-ttwkv7-unstable-2026-06-22`, the unchanged immutable kernels, selected P150 device 1, seven patterns, and lengths 1 and 32. This does not establish full-WKV, decode, performance, or general P150 compatibility. Evidence is retained at `/var/tmp/ttwkv7-constant-probe-20260716T185657Z`.

## Risks / Trade-offs

- Fake-target execution proves argument semantics but not hardware behavior; actual production path inspection and the pinned self-test independently cover composition without device access.
- The repaired process may expose a Metalium initialization or mask defect. That is a valid terminal result, not authorization to retry.
- Owner restart can take time. The runbook retains bounded endpoint polling, independent rollback, service/container state, and two board snapshots.
- The deterministic full-WKV numerical failure remains out of scope.

## Search Budget

Repair search used three argument-preservation mechanisms, one secondary adversarial review, and focused deterministic checks. The explicit-mode candidate passed its adversarial oracles. The one-process physical search terminated validated with fourteen unique exact passes, one final pass marker, process status zero, and healthy restoration.
