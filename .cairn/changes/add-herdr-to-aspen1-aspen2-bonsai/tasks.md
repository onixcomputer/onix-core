# Add Herdr to Aspen1, Aspen2, and Bonsai

## Phase 1: Machine and profile integration

- [x] [serial] Install the wrapped Herdr package on Aspen1 without removing existing packages. r[onix.herdr.fleet.aspen1]
- [x] [serial] Install the wrapped Herdr package on Aspen2 without removing existing packages. r[onix.herdr.fleet.aspen2]
- [x] [serial] Install the wrapped Herdr package on Bonsai without removing existing packages. r[onix.herdr.fleet.bonsai]
- [x] [serial] Expand the explicit Herdr Home Manager instance while preserving Aspen3 and desktop assignments. r[onix.herdr.fleet.profile]

## Phase 2: Verification

- [x] [serial] Evaluate all requested machines and exercise the wrapped Herdr with their generated config. r[onix.herdr.fleet.verification]
- [x] [serial] Document the installation and rollout boundary and run Cairn validation. r[onix.herdr.fleet.verification]

## Evidence

- Focused Nix evaluation selects `/nix/store/ld4m7v96mgqfj5rwfv3z2cvf0dbc0pxa-herdr` and the same generated TOML and Neovim adapter on Aspen1, Aspen2, Bonsai, Aspen3, and britton-desktop.
- The selected wrapper was built and reports Herdr `0.9.3`. In an isolated temporary home, `herdr config check` reports `config: ok`, and `herdr plugin list --json` returns exactly the seven bundled plugin ids without creating a mutable plugin registry.
- Aspen2 and Bonsai full system derivation evaluations pass. Aspen1 full system evaluation is blocked by the existing `radicle-node-1.10.3` insecure-package policy; no security-policy exception was added.
- Cairn validation passes with no issues. The canonical Git-flake checkout and policy paths under `/home/brittonr/git/OnixResearch/cairn` avoid the `cairn` symlink and socket-copy failures of the documented path-flake invocation.
- No remote NixOS/Home Manager generation was activated and no running Herdr session was restarted.
