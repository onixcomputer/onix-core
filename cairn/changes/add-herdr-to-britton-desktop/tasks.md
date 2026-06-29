## Phase 1: Add Herdr declaratively

- [x] [serial] Add a narrow `nixpkgs-herdr` input pinned to a nixpkgs revision that exposes `herdr`. r[onix.britton-desktop.herdr.source]
- [x] [serial] Use the nixpkgs `herdr` package from the narrow pinned package set. r[onix.britton-desktop.herdr.source]
- [x] [serial] Add Herdr to `britton-desktop` system packages without removing existing package entries. r[onix.britton-desktop.herdr.install]

## Phase 2: Validate

- [x] [serial] Evaluate the `britton-desktop` system derivation before the change to establish a baseline. r[onix.britton-desktop.herdr.verification]
- [x] [serial] Evaluate the `britton-desktop` system derivation after the change. r[onix.britton-desktop.herdr.verification]
- [x] [serial] Verify the rendered package list includes `herdr` and does not accidentally match a bogus Herdr package name. r[onix.britton-desktop.herdr.package-list]
