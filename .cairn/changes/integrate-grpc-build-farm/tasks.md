## Phase 1: Implementation

- [x] [parallel] Pin compatible gRPC and Niks3 sources and build against the existing Nix fork. r[onix.build_farm.abi]
- [x] [parallel] Implement node, balancer, client, and offline PKI roles. r[onix.build_farm.authentication]
- [x] [serial] Migrate managed routing and admit two non-recursive workers. r[onix.build_farm.topology]
- [x] [serial] Enable bounded automatic farm publication without draining maintenance queues. r[onix.build_farm.publication]
- [x] [serial] Exercise authenticated scheduling, cache reuse, and denied access; validate configuration and record evidence. r[onix.build_farm.verification]

## Phase 2: Production deployment

- [x] [serial] Inspect live host access and deployment controls. r[onix.build_farm.verification]
- [ ] [serial] Back up Niks3 metadata before the server migration. r[onix.build_farm.publication]
- [x] [serial] Generate production CA, worker, balancer, and client certificates. r[onix.build_farm.authentication]
- [ ] [serial] Deploy Aspen1 and verify cache, scheduler, worker, and ingress health. r[onix.build_farm.topology]
- [ ] [serial] Deploy Aspen2 and verify worker registration. r[onix.build_farm.topology]
- [ ] [serial] Deploy all three clients after both workers are healthy. r[onix.build_farm.topology]
- [ ] [serial] Exercise live scheduling, signed retrieval, and cache reuse. r[onix.build_farm.verification]
- [x] [serial] Record production evidence and validate Cairn. r[onix.build_farm.verification]

## Phase 3: Deployment preparation

- [x] [serial] Pin client ingress name resolution to the Tailnet address and exercise generated hosts files with libc. r[onix.build_farm.topology]
- [x] [serial] Prebuild all five deployment closures with the generated credentials. r[onix.build_farm.verification]
- [x] [serial] Replace `britton-fw` with the already-admitted Bonsai client and retire the unused credential. r[onix.build_farm.authentication]

Production activation remains blocked on Aspen1 SSH recovery and its pre-upgrade database backup. No live machine was switched.

All five deployment closures are built: Aspen1, Aspen2, Aspen3, Bonsai, and britton-desktop. The three desktop Tenstorrent compatibility repairs pass their package checks and host-only smoke checks. The desktop kernel was built on Aspen2 and imported without changing either running system. The actual pre-upgrade backup invocation still fails before SSH authentication on Aspen1. Exact derivations, errors, source recovery, and successful output paths are recorded in `deployment-evidence.json`.

## Phase 4: Authorized deployment blocker repair

- [ ] [parallel] Recover Aspen1 administrative access without bypassing host authentication. r[onix.build_farm.verification]
- [x] [parallel] Rebase fetch-queue diagnostics onto the pinned TT-Metal SDK without removing diagnostics. r[onix.build_farm.verification]
- [x] [parallel] Migrate RWKV tensor construction to the pinned SDK without changing tensor semantics. r[onix.build_farm.verification]
- [x] [parallel] Migrate llama.cpp Metalium headers and APIs while preserving Blackhole support. r[onix.build_farm.verification]
- [ ] [serial] Verify repaired packages and desktop closure, then complete the staged rollout and live acceptance checks. r[onix.build_farm.verification]
