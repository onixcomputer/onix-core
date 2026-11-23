# Design

## Context

Reuse existing systemd state/socket and Clan schema conventions. Package only actual executable interfaces; do not infer unpublished CLI capabilities from Rust types or library envelopes. Preserve existing static VM and no-network CI profiles unchanged.

## Decisions

Use separate service users, immutable policy/configuration, systemd scoped credentials, bounded execution and durable SQLite paths. Poll intake separately from explicitly admitted attempt dispatch and privileged verification/publication. A fresh process never creates fresh semantic budget. Stop ambiguous attempts until provider reconciliation; never retry dispatch by process supervision.

Build guest kernel/initrd/root/runtime/tool closure from one Nix cohort, read-only root with independent workspace/state/Nix writable volumes and generated machine identity. Bind actual dereferenced Cloud Hypervisor executable digest and version, generated launch arguments, explicit raw disk type, memory backing and mergeability. Admission compares both hosts and fails closed absent exact-profile boot/migrate/restore evidence. Root immutable environment closures on both hosts; retire references explicitly, not on process exit.

## Qualification

Provide positive and negative evaluation cases, local device-free boundary tests and executable preflight/qualification entrypoints. Scripted evidence is never live-worker evidence. Real KVM, PR, cross-host inference and advanced recovery/residency profiles require exact producer interfaces, qualified model/engine/host observations and operator authority; unsupported profiles remain independently unqualified.

The scripted VM profile composes the actual NixOS service module and owner executables from a strict immutable cohort, typed policy/configuration, exact attempt bundle and canonical Engine profile. The harness accepts these as explicit inputs rather than selecting the deployed canary pins or synthesizing a passing cohort. At VM start it resolves each manifest executable, verifies its declared digest, and checks native CLI capabilities before enabling any stage; missing inputs fail before qualification. Scripted model and local GitHub provider fixtures supply deterministic external responses only inside the isolated VM. They do not replace OMP, Kiln, Lattice, Cairn, the trusted verifier, or canonical CI, and their evidence is separately labeled from live-worker/guest profiles.

## Risks and alternatives

Existing pins predate new functionality. Require explicit package/config identity adoption without editing flake.lock manually. Do not create a competing workflow engine, scheduler, inference supervisor or generic command daemon. Never clone host keys into reusable guest content.
