# Deploy admitted RWKV-7 persistent decode window 8

## Why

`tenstorrent.nix` now admits bounded persistent decode windows `[2, 4, 8]`, but `onix-core` still pins the earlier `[2, 4]` package set. The active `britton-desktop` closure cannot expose the accepted profile v3 through stable system paths.

## What changes

- Update the generated lockfile to pin `tenstorrent.nix` revision `b1e5ff766e9c4e656b5cb1f15356d46c95d832c4`.
- Build the exact `britton-desktop` system closure from that lock.
- Activate that exact closure without rebuilding during activation.
- Verify the installed runtime and evidence commands.
- Verify production profile `rwkv7-p150x2-persistent-decode-v3`, its BLAKE3 identity, and admitted windows `[2, 4, 8]`.
- Retain a deployment receipt and the prior closure path for rollback evidence.

## Impact

The host receives the already accepted production package set. This change does not run a new admission experiment, change runtime policy, create a daemon, route live traffic, or weaken an interlock.
