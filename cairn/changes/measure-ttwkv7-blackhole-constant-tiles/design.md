## Context

The previous one-shot probe reached Blackhole single-chip mesh discovery but failed before JIT or mask comparison because default Metalium diagnostics attempted to create `generated/watcher` beneath a read-only package working directory. Its authorization was exhausted without measuring any tile. The focused runtime introduced by commit `4910b700c08f4320ef0ed8f03973f01578f9b2ce` now fails before device initialization unless `TT_METAL_CACHE`, `TT_METAL_LOGS_PATH`, and `TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS` identify explicit safe runtime state.

The reviewed package is `/nix/store/plr5vlpv1q5g4zl6c2q065bwsmbhxkrr-ttwkv7-unstable-2026-06-22`. The reviewed evidence root is `/var/tmp/ttwkv7-constant-probe-20260716T160230Z`, Inspector address is `127.0.0.1:43127`, physical device is 1, and its owner is `docker-tt-inference-server-llama-3-1-8b-instruct-p150.service`.

## Success Contract

Success requires all seven generated patterns at lengths 1 and 32 to compare exactly across all 32-by-32 BF16 elements in one process invocation. A passing preflight, successful initialization, JIT compilation, a passing subset, plausible values, relaxed tolerances, or service recovery alone is not success.

Allowed terminal outcomes are:

- **validated**: all fourteen tiles pass exactly;
- **mask-mismatch**: the process reports a first mismatch and nonzero mismatch count;
- **initialization-blocked**: the one invocation returns nonzero before mask comparison;
- **timed-out**: the one invocation exceeds the reviewed hard bound; or
- **isolation-blocked**: owner isolation cannot be proven, so no probe invocation occurs.

Every outcome forbids automatic retry. Any later probe requires another reviewed change and separate authorization.

## Authorization Boundary

The user's `do it` instruction on 2026-07-16 explicitly authorizes exactly one probe-mode invocation under this change after proposal, design, task, package, architecture, and no-device preflight gates pass. It does not authorize deployment, activation, source changes, full-WKV execution, a second device open, or retry after any process status.

The invocation is bound to:

- package `/nix/store/plr5vlpv1q5g4zl6c2q065bwsmbhxkrr-ttwkv7-unstable-2026-06-22`;
- the immutable kernel target resolved from that package;
- `TT_VISIBLE_DEVICES=1`;
- cache and logs beneath `/var/tmp/ttwkv7-constant-probe-20260716T160230Z`;
- Inspector RPC address `127.0.0.1:43127`;
- owner service `docker-tt-inference-server-llama-3-1-8b-instruct-p150.service`; and
- one 180-second hard timeout.

## Decisions

### Decision: Execute the exact store output without deployment

**Choice:** Invoke the reviewed package path directly from the managed host's Nix store.

**Rationale:** The focused package already composes the reviewed host binaries, immutable kernels, and runtime wrapper. Activation would add SSH/SOPS risk without changing this diagnostic.

### Decision: Preflight mutable state before service isolation

**Choice:** Run `validate-runtime`, verify the Inspector port is unused, and capture package/kernel identities before stopping the owner service.

**Rationale:** A runtime-state mistake must fail without disrupting the service or touching a device.

### Decision: Count at the process boundary

**Choice:** Initialize the invocation count to zero and set it to one immediately before the single timeout-wrapped `probe` command.

**Rationale:** Any process outcome after that boundary consumes authorization, including initialization failure, signal, or timeout.

### Decision: Restore only prior active state

**Choice:** Record whether the owner service was active, stop and prove it inactive before the probe, and use an exit trap to restart it only when it was active initially.

**Rationale:** Restoration must be guaranteed without inventing a new service state.

## Approach Registry

| Family | Mechanism | Evidence | Next check | State |
|---|---|---|---|---|
| Runtime state | Explicit writable cache/log paths remove the prior read-only boundary | Packaged preflight and focused install checks pass | One reviewed initialization | active |
| SFPU finalization | Blackhole reset-aware finalizer produces correct constants | Both architecture paths compile; masks remain unmeasured | Exact fourteen-tile output | independent |
| Destination mapping | Blackhole destination lanes permute logical coordinates | No tile output exists yet | Classify first mismatch geometry | independent |
| WKV arithmetic/layout | Failure occurs after constants | Earlier full-WKV NMSE is near one | Consider only after all masks pass | blocked |
| Tolerance | A looser threshold would hide errors | Masks contain exact zero/one BF16 values | None | falsified |

## Adversarial Audit

Writable directories do not prove device safety or numerical correctness. The run must reject a busy Inspector port, prove the owner inactive, retain exactly one invocation count, preserve the raw process status, and avoid shell constructs that accidentally rerun the probe. A passing result establishes only the reviewed package's fourteen masks on the selected P150. A failure must remain failure evidence rather than trigger repair or retry inside this change.

## Risks / Trade-offs

- Stopping the owner service temporarily removes the device-1 inference endpoint; the trap restores its prior active state.
- A hard timeout may terminate Metalium during initialization; it still consumes the invocation and requires post-run board/service evidence.
- TT-SMI health reads are evidence collection, not additional ttWKV7 process invocations.
- Existing SSH/SOPS activation failures are deliberately avoided because no deployment is required.

## Validation Evidence

The focused package check and pinned Blackhole/Wormhole architecture check passed at commit `4910b700c08f4320ef0ed8f03973f01578f9b2ce`. The exact composed output resolved to `/nix/store/plr5vlpv1q5g4zl6c2q065bwsmbhxkrr-ttwkv7-unstable-2026-06-22`, and its kernel link resolved to `/nix/store/8m898sjjhcvva2l8375r1wi5alp6cmj3-ttwkv7-kernels-unstable-2026-06-22/share/ttwkv7/kernels`. Before preflight, `127.0.0.1:43127` was not listening and the owner service reported `ActiveState=active`, `SubState=running`, `Result=success`, and `NRestarts=0`. The exact package's `validate-runtime` mode created the reviewed cache/log directories and passed while the invocation count remained zero. The one-shot orchestration script passed Bash syntax, ShellCheck, tree formatting, and Cairn gates without stopping a service or executing probe mode.

## Search Budget

Primary authority is the pinned package, Metalium runtime, service manager, and retained local evidence. The physical search budget is exactly one ttWKV7 device-owning process invocation. The budget terminates at its first process result; no correlated retry or alternate command is permitted.
