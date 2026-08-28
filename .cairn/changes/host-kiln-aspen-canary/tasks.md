## Phase 1: Dependency preflight

- [x] [serial] Audit the current Seaglass broker command and prove it does not select Aspen. r[onix.kiln_aspen_canary.preflight]
- [x] [serial] Audit the reviewed Aspen and Kiln revisions for a deployable host, server transport, effect adapter, and materialized completion. r[onix.kiln_aspen_canary.preflight]
- [x] [serial] Reject `LocalAspenService`, Aspen test support, and recording-only effect ports as deployment evidence. r[onix.kiln_aspen_canary.preflight]

## Phase 2: Upstream runtime contracts

- [x] [serial] Add exact materialized effect-completion delivery to Aspen with positive and negative tests. r[onix.kiln_aspen_canary.completion]
- [x] [serial] Add a Kiln-owned host bridge for the Kiln Unix protocol and Aspen service ingress. r[onix.kiln_aspen_canary.composition]
- [x] [serial] Add a concrete bounded Lattice workflow effect adapter and exact terminal mapping. r[onix.kiln_aspen_canary.completion]
- [x] [serial] Prove missing completion bytes remain rejected or `Unknown`. r[onix.kiln_aspen_canary.completion]

## Phase 3: Onix Core module

- [x] [serial] Pin the reviewed Aspen, Kiln, and Lattice revisions through Nix-generated lock updates. r[onix.kiln_aspen_canary.preflight]
- [x] [serial] Add the separate disabled-by-default Clan module with typed Nickel settings. r[onix.kiln_aspen_canary.composition]
- [x] [serial] Add separate users, state roots, sockets, ordering, and systemd resource bounds. r[onix.kiln_aspen_canary.authority]
- [x] [serial] Add positive module checks and negative profile, endpoint, authority, fallback, and existing-route fixtures. r[onix.kiln_aspen_canary.failure]
- [x] [serial] Add the operator-only canary client without changing the Seaglass broker trigger. r[onix.kiln_aspen_canary.failure]

## Phase 4: Evidence and closeout

- [x] [serial] Run package, module, machine-evaluation, Cairn, and focused Nix checks. r[onix.kiln_aspen_canary.evidence]
- [x] [serial] Derive the Lattice connection bound from the host request and provider poll bounds. r[onix.kiln_aspen_canary.composition]
- [x] [serial] Remove only each service's type-checked stale socket before restart. r[onix.kiln_aspen_canary.failure]
- [x] [serial] Run the uncertainty drill as the host identity without root impersonation. r[onix.kiln_aspen_canary.authority]
- [ ] [serial] Deploy the private canary to `britton-desktop` and run accepted, rejected, unavailable, and uncertain drills. r[onix.kiln_aspen_canary.evidence]
- [ ] [serial] Retain the exact bounded receipt and verify every deployment non-claim. r[onix.kiln_aspen_canary.evidence]
- [ ] [serial] Sync and archive only after all dependency and live evidence gates pass. r[onix.kiln_aspen_canary.evidence]
