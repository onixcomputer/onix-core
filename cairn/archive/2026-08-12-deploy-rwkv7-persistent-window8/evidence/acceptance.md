# Acceptance

## Decision

The RWKV-7 P150x2 production profile v3 is deployed on `britton-desktop`.

The active system closure is:

`/nix/store/vnaw887lbpk2fzk0z65i1km3pv9qzyr1-nixos-system-britton-desktop-26.11.20260803.104240a`

Activation used that exact store path through `bin/switch-to-configuration`. The prior closure remains the rollback target:

`/nix/store/9sz5xr2hyp5fsivyi633jd5b15xs37m9-nixos-system-britton-desktop-26.11.20260803.104240a`

## Package and profile evidence

The generated lockfile pins `tenstorrent.nix` revision `b1e5ff766e9c4e656b5cb1f15356d46c95d832c4`. That revision contains admission commit `8089efa5d0bcffca6e7ac42f73cb2bfcf97935c6`.

The active closure provides these stable commands:

- `/run/current-system/sw/bin/rwkv7-p150x2-runtime`
- `/run/current-system/sw/bin/rwkv7-p150x2-persistent-decode-monitor`

The installed profile is `rwkv7-p150x2-persistent-decode-v3`. Its BLAKE3 is `c5bfa37d83c026bfdb9255da4810bc90af71c7a0e949f05c9c5bf3e709654568`. It is physically admitted and lists windows `[2, 4, 8]`.

## Build blocker and repair

The first target closure build failed because the evidence package ran the CPU reference through Torch without NumPy. The package now includes NumPy in its Python environment. The focused evidence build and the full host build passed after revision `b1e5ff766e9c4e656b5cb1f15356d46c95d832c4`.

## State restoration

Activation restarted both managed Tenstorrent inference units. The deployment restored their prior inactive state. Both units are now inactive, and devices `0` and `1` have no open owner.

## Non-claims

This deployment did not run decode. It does not add correctness, performance, determinism, or admission evidence. The accepted evidence remains in the pinned `tenstorrent.nix` archive.
