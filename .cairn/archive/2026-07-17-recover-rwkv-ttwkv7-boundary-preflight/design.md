# Design: Recover the ttWKV7 boundary preflight

## Observed terminal boundary

The sole authorized orchestration command was pueue task 64 invoking the archived argument-free runbook. It stopped at loopback host-key validation with expected fingerprint `SHA256:0vd1vzTWrAONyquNKjwnsGY7a5bY2NJlvFamtxy/akY` and observed fingerprint `SHA256:DOOddCNRRRqCVbueQZovbR8Q//NwYeeMCaznz+GqxQE`.

The root `/var/tmp/rwkv-ttwkv7-boundary-device-1` is terminal and SHALL NOT be removed, renamed, reused, or treated as hardware evidence. Its execution, process, owner-isolation, restoration, service-stop, and rollback counters are all zero. A separately materialized `rwkv-lab` receipt classifies plan `bdbc6834b6ba3da6e1404858697a01d68d1f58734401d81f4a0f0d2999a5b239` as `not_run`, with process budget unexhausted, no safety issues, no success claim, and all hardware artifact roles and the success marker absent. The ordered evidence-hash file has BLAKE3 `45cc0eaaf938b09e53aa5e52422536f44189b284ff1d99b9062548f0db2da9d5`.

## Functional core

The existing typed Nickel session contract and pure `rwkv-lab` classifier remain authoritative. A checked-in typed Nickel preflight receipt binds the command, plan, expected and observed host fingerprints, all zero counters, classification hash, raw known-hosts hash, ordered evidence identity, and narrow non-claims. The Nix readiness check exports and verifies this receipt without reading `/var/tmp`.

The package's session-plan source receives named session/root substitutions. The recovery instance uses a distinct session ID and `/var/tmp/rwkv-ttwkv7-boundary-device-2`; the original plan and root remain immutable evidence. Package, fixture, device 1, owner unit, owner helper, runtime executable, kernels, one-process budget, timeout, kill grace, rollback delay, and evidence roles are unchanged.

## Imperative shell

The corrected runbook is argument-free and pins the rebuilt plan/package/readiness identities plus the current ED25519 fingerprint. After atomically creating the second root and writing zero counters, it installs a terminal trap before host-key, wrapper, service, health, and board preflight.

The trap distinguishes pre-isolation from post-isolation exits. Before isolation it SHALL NOT claim restoration, board health, or owner health; it emits zero-attempt `not_run` classification with nullable recovery fields and preserves the failure diagnostic. After isolation it retains the existing unconditional local restore, independent rollback cancellation, owner-health checks, board evidence, complete artifact validation, and `rwkv-lab` classification.

Exactly one wrapper `probe` remains the only device process source. The execution lock is written immediately before the process counter and probe. There is no retry, fallback, direct runtime call, alternate test/bench command, prompt gate, authorization file, or second process.

## Validation

Run the historical package and readiness check before changes. After changes, build the new package and readiness check; replay the typed plan and `not_run` receipt; verify the preserved preflight receipt; run syntax, formatting, source checker positive/negative fixtures, closure, architecture, host-layout, decode-reader, shape, and data-movement gates; and validate in a clean detached worktree.

Do not invoke either runbook, create the second root, inspect a Tenstorrent device, call `tt-smi`, query owner health, alter the owner service, initialize Metalium, or execute a kernel during this change.

## Non-claims

This recovery does not authorize a second run. It does not establish repaired-reader completion, numerical ttWKV7 correctness, physical P150 correctness, owner restoration under an actual isolated run, complete RWKV layers, generation, serving, throughput, or latency.

## Validation evidence

The authorized pueue task 64 executed the archived argument-free runbook exactly once and stopped with `loopback host fingerprint mismatch`. The first root remains at `/var/tmp/rwkv-ttwkv7-boundary-device-1`. Its process, execution, owner-isolation, restoration, service-stop, and rollback counters are zero. The run checked device-path metadata but did not query the board, open the device, initialize Metalium, execute a kernel, or change the owner. The deterministic classification receipt has BLAKE3 `a7169162e27db4a98b6b3cca834f1e601739ccd7c7398ad49ccd32bc09f38190`, outcome `not_run`, unexhausted process budget, no safety issues, and no success claim. The ordered evidence-hash file identity is `45cc0eaaf938b09e53aa5e52422536f44189b284ff1d99b9062548f0db2da9d5`.

The typed preflight evidence source has BLAKE3 `f2cbaaeb936a2e8ab435b7ea3c046a1cd29c6acc48b9b39a829a487db487fcb1`; its exported JSON has BLAKE3 `ff37d0a0f54d9c99c373d2815613acb9d02f1c6d230146755e2f6cbe34ec5e69`. The readiness check independently exports and verifies every zero counter, expected and observed fingerprint, missing artifact, missing marker, raw evidence identity, and narrow device-path/open/Metalium/kernel/owner claims.

The recovery package is `/nix/store/av4m3qy5m0qjvrrfrn1dckjxnd7vzbkv-rwkv-ttwkv7-boundary-device-0.2.0`. Its session ID is `rwkv-ttwkv7-boundary-device-2`, plan ID is `d4886116b76df2cf63090e3a1f7efff35aa215aa2d05652d7accaa9b61a9abb1`, plan receipt BLAKE3 is `307efa0052ae9b5b003d7c6026ba0340e527cbea4a6e057bfa70df84c53e0291`, and initial `not_run` receipt BLAKE3 is `d2c21fd3646654ce1045e22cc43ccf7c093aa14f32de5fc132879377acd455bd`. The distinct root is `/var/tmp/rwkv-ttwkv7-boundary-device-2`. The readiness output is `/nix/store/hjjrp20xidsgig1yzfn5zydbn9wp8n7a-rwkv-ttwkv7-boundary-device-check`; its receipt BLAKE3 is `bac896f69c9d2f8c68764aafd696c9902d21220e3368a0bfe92f7b976e8a2d1e`.

The corrected runbook is 21,269 bytes, mode `0755`, with BLAKE3 `644ca05ac6a358002d9139358d9769660b87ee2133e24ea07f132101861a5df7`. It pins the new plan/readiness identities and observed ED25519 authority, binds the plan root, installs terminal traps immediately after atomic root creation, leaves recovery fields nullable before isolation, and disarms any partially armed rollback before pre-isolation classification. The checker is 14,255 bytes, mode `0755`, with BLAKE3 `7295957f13c51e3ee66613834e4b50e92e1c761e1ce142774697f1d7ad145696`. Positive validation, syntax validation, and adversarial self-test pass; mutations cover package, readiness, plan, device, root, fingerprint, timeout, rollback delay, trap position, host-key scan, pre-isolation classification and rollback cleanup, lock/counters, owner isolation/restoration, wrapper count, evidence validation, direct runtime, retries, arguments, and authorization gates.

A bounded three-family audit checked immutable typed plan/root separation, shell trap/rollback state transitions, and adversarial source mutations. The shell-state audit found and repaired the race where a rollback timer could become active immediately before a pre-isolation exit. Advisory review supplied no accepted validation claim; deterministic checks are authoritative.

Final software-only outputs are `/nix/store/5alwcj7ff65s1zg6q475akwayafmh0bz-ttwkv7-unstable-2026-06-22`, `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`, `/nix/store/1yk29inrvfwvm9xs4ny7r8jsxls15zpj-rwkv-ttwkv7-host-layout-check`, and `/nix/store/360la0zgb3f9wb2f8dmkjy17qdl7w3lq-rwkv-ttwkv7-decode-reader-check`. Package/install checks, closure isolation, checkpoint shape, synthetic data movement, boundary self-test, plan replay, initial classification replay, focused formatting, and clean detached-worktree Cairn validation and proposal/design/tasks gates pass.

Cairn sync added the accepted recovery requirement with receipt `5c359e7bf859e53c161f155286b25e646bf2043f87f00c793d9c2b5dbbbb7e81`; archive execution produced receipt `6bfaaa861d83b348e2055f9e386e867ae98de10379284f4ecc2a89f2e7ba8e2d`. Clean post-archive validation reports `changes: 0`, `valid: true`, and no issues or substance issues. The corrected runbook was not invoked, and `/var/tmp/rwkv-ttwkv7-boundary-device-2` remains absent. No second authorization was inferred from the first authorization.
