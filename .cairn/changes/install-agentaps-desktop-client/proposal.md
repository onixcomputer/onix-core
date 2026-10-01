## Why

Agentaps is a GPUI desktop client for coding agents that speak the Agent
Client Protocol (ACP). It runs agents in local folders or over SSH and can
pair a phone browser through Iroh. The two workstations that already run
the terminal agents, `britton-desktop` and `aspen3`, should also have it.
Agentaps is not in nixpkgs or `llm-agents.nix`, so it needs a package
definition. onix-core keeps package definitions in onixpkgs.

## What Changes

- Add `pkgs/agentaps` to onixpkgs. It pins upstream `main` at `9d526af`
  (2026-09-28) and publishes onixpkgs `main` to `origin` and `rad`.
- Relock onix-core's `onixpkgs` input to that revision.
- Add `agentaps` to `brittonr`'s Home Manager packages on `britton-desktop`
  and `aspen3`.
- Port the addition onto the commit `britton-desktop` runs (`e8d1a26c` on
  `underclass-mesh-desktop`). That lineage predates the onixpkgs overlay, so
  the port adds the `onixpkgs` input and takes `agentaps` from that flake's
  `packages` output.
- Deploy each machine from the lineage it runs and confirm `agentaps`
  resolves on `brittonr`'s `PATH`.

## Impact

- **Files**: `flake.lock` (`onixpkgs` node only),
  `machines/britton-desktop/configuration.nix`, and
  `machines/aspen3/configuration.nix`. On the desktop lineage: `flake.nix`,
  `flake.lock` (new `onixpkgs` and `horizon_2` nodes), and
  `machines/britton-desktop/configuration.nix`. In onixpkgs:
  `pkgs/agentaps/default.nix` and `README.md`.
- **Risk**: The pin is 52 commits past the v0.2.1 release, so it can carry
  unreleased defects. The first build compiles GPUI from source.
- **Non-goals**: no ACP adapters or agent credentials, no SecretSpec provider
  for phone pairing, no Web Connect site, and no other machines.
- **Testing**: build the package and inspect how it loads its GPU and
  windowing libraries. Launch it on a headless Wayland compositor. Evaluate
  both machines' package lists, build both toplevels, and compare their
  closures with the running systems before activation. After deploy,
  resolve the executable on both hosts.

## Affected Specs

- `workstation-tools`: Agentaps installation, source, and deployment.
