## Why

Install the requested Underclass subscription-pooling proxy on the managed OMP workstations and expose it through OMP without replacing existing providers or copying rotating OAuth credentials.

## What Changes

- Pin the upstream Underclass flake, reusing existing nixpkgs, systems and devenv inputs.
- Enable a loopback-only persistent service on `britton-desktop`; `aspen3` shares that pool over an SSH tunnel. Install `underclass` and `utop`.
- Generate separate per-machine client and admin credentials with Clan vars, outside the Nix store.
- Install an additive native OMP provider using Underclass's Responses endpoint.

## Impact

- **Files**: flake inputs/lock and tool exports, common NixOS module imports, `modules/llm-agents`, service inventory, native Cairn artifacts.
- **Testing**: build the pinned package and managed extension, evaluate selected/unselected machines, exercise authenticated catalog and empty-pool requests through the real proxy and OMP, run focused existing checks and Cairn validation.
