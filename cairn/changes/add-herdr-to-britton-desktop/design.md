## Context

Herdr is available in current nixpkgs, but the root nixpkgs pin does not expose `pkgs.herdr`. A root nixpkgs bump makes unrelated `pnpm-10.29.2` insecurity handling block `britton-desktop` system evaluation, so this change uses a narrow `nixpkgs-herdr` input for Herdr only. The `britton-desktop` module already installs a few machine-specific tools directly from `environment.systemPackages`, including packages exposed by this repo's flake outputs.

## Decisions

### 1. Use nixpkgs Herdr

**Choice:** Use `inputs.nixpkgs-herdr.legacyPackages.${pkgs.stdenv.hostPlatform.system}.herdr` from a narrow nixpkgs input pinned to a revision where that package exists.

**Rationale:** `nix-shell -p herdr` confirms Herdr is packaged in nixpkgs. A narrow nixpkgs input keeps the source as nixpkgs, avoids a separate Herdr flake input or local package derivation, and avoids the unrelated fallout from advancing the root nixpkgs pin.

### 2. Install directly in `britton-desktop`

**Choice:** Add `herdr` to `machines/britton-desktop/configuration.nix` inside the existing `with pkgs;` package list.

**Rationale:** This keeps the change scoped to the requested machine and avoids exposing Herdr as an onix-core package when no local wrapper or overlay is needed.

## Risks / Trade-offs

- The installed Herdr version follows the narrow `nixpkgs-herdr` pin until root nixpkgs catches up.
- Two nixpkgs pins are temporarily present, but only the Herdr package is sourced from the narrow pin.
