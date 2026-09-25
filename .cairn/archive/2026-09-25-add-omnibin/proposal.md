## Why

`omnibin` (`github:fzakaria/omnibin`) serves every executable nixpkgs ever
shipped from a lazy `/nix/store`. A pinned SQLite index answers names and file
listings; a store path's bytes are fetched from cache.nixos.org the first time
a file in it is read. Any historical tool version, such as `python3@3.6.2`,
then runs without being installed and without guessing a package set ahead of
time. That fits agent work on the desktop.

## What Changes

- Add the `omnibin` flake input, following the repository `nixpkgs`.
- Add an `omnibin` tag that installs the `omnibin` CLI with its pinned index
  and `omnibin-shell`, and assign the tag to `britton-desktop`.
- Leave the input's NixOS module out. It mounts a read-only FUSE store over
  the host's `/nix/store`.
- Deploy `britton-desktop` from the lineage it already runs.

## Impact

- **Files**: `flake.nix`, `flake.lock`, `inventory/tags/omnibin.nix`,
  `inventory/core/contracts.ncl`, `inventory/core/machines.ncl`.
- **Risk**: the pinned x86_64 index adds about 261 MB to the system closure.
  `omnibin-shell` downloads a package the first time it is used and unpacks it
  into `~/.cache/omnibin`, and nothing evicts that cache.
- **Non-goals**: no system-wide lazy `/nix/store`, no `omnibin` system
  service, no other machine, and no change to existing lock nodes.
- **Testing**: package-list evaluation (`britton-desktop` positive, `aspen3`
  negative), the tag registry check, builds of both packages, an
  `omnibin-shell` run of a binary the host store does not hold, a closure
  comparison before activation, and resolution of both commands on the target.

## Affected Specs

- `workstation-tools`: omnibin source, scope, host-store boundary,
  verification, and deployment.
