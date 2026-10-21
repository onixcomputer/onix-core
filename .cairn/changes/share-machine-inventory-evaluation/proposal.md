## Why

Direct Nix consumers repeatedly evaluate the same contract-validated `inventory/core/machines.ncl` through WASM. A fresh-process probe on britton-desktop measured 2.907 seconds of CPU for one parse versus 4.357 seconds for ten. Sharing the result can remove this repeated work without changing machine configuration.

## What Changes

- Evaluate the raw machine definitions once per flake evaluation, independently of Clan configuration.
- Reuse that value in the existing machine library, Clan inventory projection, NixOS `nclMachines` argument, and machine, builder, SSH-host-key, and vars checks.
- Preserve machine fields, names, tag membership, check membership, and generated configurations. Do not deploy, update inputs, or change services.

## Impact

- **Files**: `flake-outputs/clan.nix`, `inventory/default.nix`, `inventory/core/default.nix`, `inventory/tags/common/wasm-lib.nix`, and the four affected check modules.
- **Testing**: Compare raw definitions and Clan projections, names and tag queries, check names for supported platforms, generated machine configuration, and repeated fresh-process timings with evaluation caching disabled.
- **Boundary**: The current nixpkgs input already rejects `x86_64-darwin` check enumeration. This change does not alter the input or platform declarations.
