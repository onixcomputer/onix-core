## Phase 1: Personal service

- [x] [serial] Add the desktop-only personal Radicle profile and supervised runner for r[onix.radicle_replica.personal_supervision] and r[onix.radicle_replica.personal_signer].
- [x] [serial] Add desktop lingering and the managed-port user-slice guard for r[onix.radicle_replica.personal_persistence] and r[onix.radicle_replica.personal_listener].

## Phase 2: Validation

- [x] [serial] Add positive desktop and negative non-desktop service-shape checks for r[onix.radicle_replica.personal_validation].
- [x] [serial] Run focused Home Manager, desktop system, Radicle replica, formatting, and Cairn checks for r[onix.radicle_replica.personal_validation.positive].

## Phase 3: Deployment and lifecycle

- [x] [serial] Activate the exact generated user unit, enable linger, and record live restart, socket, identity, and status evidence for r[onix.radicle_replica.personal_supervision.restart].
- [x] [serial] Sync the accepted specification and archive this change with bounded evidence for r[onix.radicle_replica.personal_validation].
