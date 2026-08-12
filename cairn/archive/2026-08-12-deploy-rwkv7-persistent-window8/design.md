# Design

## Goal

Deploy the accepted RWKV-7 P150x2 production profile v3 on `britton-desktop` through one exact, rollback-safe NixOS closure.

## Package boundary

`onix-core` consumes `tenstorrent.nix` through its generated `flake.lock`. The target revision is `b1e5ff766e9c4e656b5cb1f15356d46c95d832c4`. It contains admission commit `8089efa5d0bcffca6e7ac42f73cb2bfcf97935c6` and the required NumPy package fix. Existing package selection fails evaluation if the runtime or evidence output disappears.

The machine configuration already installs both outputs. Therefore, this change updates only the generated lockfile and lifecycle evidence.

## Activation boundary

Build the full `britton-desktop` closure before activation. Record the active closure and the new closure. Activate only the exact built store path through its `bin/switch-to-configuration` command over managed root SSH.

Do not run `nixos-rebuild` or another command that can evaluate a different source during activation. If activation or post-activation verification fails, switch back to the recorded prior closure.

## Verification boundary

Post-activation verification requires:

- `/run/current-system` to resolve to the exact built closure;
- stable runtime and monitor commands in `/run/current-system/sw/bin`;
- profile ID `rwkv7-p150x2-persistent-decode-v3`;
- profile BLAKE3 `c5bfa37d83c026bfdb9255da4810bc90af71c7a0e949f05c9c5bf3e709654568`;
- physically admitted windows exactly `[2, 4, 8]`;
- no change to competing service state or device ownership.

The checks do not execute decode or claim new correctness or performance evidence. Admission remains owned by the archived `tenstorrent.nix` evidence.

## Failure behavior

Any lock mismatch, build failure, closure mismatch, missing command, stale profile, or changed service state fails the deployment. The prior closure remains the rollback target. No failure changes the production admission contract.
