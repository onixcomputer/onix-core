# Tenstorrent Native Runtime Delta

## MODIFIED Requirements

### Requirement: Deploy bounded RWKV-7 persistent decode observation tools
r[onix.tenstorrent.native_runtime.rwkv7_p150x2.production_observation] The `britton-desktop` system SHALL install the package-matched RWKV-7 P150x2 runtime and evidence tools from the pinned `tenstorrent.nix` input so an operator can use bounded, fail-closed persistent decode for admitted windows `[2, 4, 8]`.

#### Scenario: Production observation tools are deployed
- GIVEN a pinned `tenstorrent.nix` revision with the physically admitted P150x2 runtime, monitoring policy, and receipt validator
- WHEN the exact `britton-desktop` system closure is built and activated
- THEN the runtime and evidence packages are present through stable system paths
- AND the installed profile is `rwkv7-p150x2-persistent-decode-v3`
- AND its BLAKE3 is `c5bfa37d83c026bfdb9255da4810bc90af71c7a0e949f05c9c5bf3e709654568`
- AND its admitted decode windows are exactly `[2, 4, 8]`

#### Scenario: Deployment uses one exact closure
- GIVEN the target closure passed evaluation and build checks and the current closure is recorded
- WHEN the operator activates the target closure
- THEN activation executes the target store path's `bin/switch-to-configuration` command
- AND post-activation verification requires `/run/current-system` to resolve to that exact target
- AND the recorded prior closure remains available as the rollback target

#### Scenario: Deployment does not create new admission evidence
- GIVEN the window `8` correctness, cleanup, profiling, speedup, and canary evidence is archived in the pinned `tenstorrent.nix` revision
- WHEN `onix-core` deploys the accepted package set
- THEN deployment verification does not run an unbounded device loop or mutate the installed profile
- AND it does not claim new correctness, performance, determinism, or admission evidence

#### Scenario: Deployment verification fails closed
- GIVEN a stale lock, missing command, wrong closure, wrong profile identity, changed service state, or unexpected device owner
- WHEN deployment verification runs
- THEN the deployment is not accepted
- AND the operator restores the recorded prior closure if activation changed the active system
