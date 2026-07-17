# Tenstorrent native runtime delta

## ADDED Requirements

### Requirement: Recover a device-free ttWKV7 boundary preflight without reusing evidence

The repository SHALL preserve a failed authorized preflight as a deterministic no-device receipt and SHALL prepare a distinct immutable session for any later hardware authorization. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_preflight_recovery]

#### Scenario: Fingerprint failure remains a narrow terminal non-run

- **GIVEN** an authorized argument-free runbook stopped before its execution lock because its pinned loopback ED25519 fingerprint differed from the observed key
- **WHEN** the repository records that terminal boundary
- **THEN** the receipt SHALL bind the exact plan, command, expected and observed fingerprints, zero process/isolation/restoration/service-stop/rollback counters, missing hardware artifacts, absent success marker, and `not_run` classification without a hardware correctness claim

#### Scenario: A later session cannot overwrite the first evidence root

- **GIVEN** the first run root contains terminal preflight evidence
- **WHEN** a recovery session is prepared
- **THEN** its typed plan SHALL use a distinct session ID and run/cache/log roots while retaining physical device 1, the accepted fixture and runtime sources, the owner service and helper, one process, fixed timeout and kill grace, independent rollback, exact evidence roles, and the narrow success claim

#### Scenario: Every post-root preflight exit classifies safely

- **GIVEN** the recovery runbook has atomically created its root but has not isolated the owner
- **WHEN** host-key, immutable-authority, wrapper, service, health, board, or ownership preflight fails
- **THEN** a preinstalled terminal trap SHALL preserve the failure, report zero process and isolation attempts, classify the plan without fabricated restoration or health claims, and SHALL NOT invoke a device process

#### Scenario: Static validation rejects a broadened attempt

- **GIVEN** the accepted recovery runbook source
- **WHEN** a fixture changes its package, plan, fingerprint, device, root, process count, timeout, rollback, trap order, execution lock, owner controls, evidence checks, wrapper command count, arguments, retry behavior, or direct runtime surface
- **THEN** the software-only checker SHALL reject the fixture without creating a runtime root, changing service ownership, accessing a device, or executing a kernel
