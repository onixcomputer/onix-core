# Release inputs

- onixpkgs commits:
  - `e1f4e3f4be47e00cad0ddee33295b6ae65362199` — omit the Collie plugin outside Linux.
  - `de18d43acc410a38a2d5eee1e1c5dd8648b4db4e` — skip the pueue plugin tests on Darwin.
- onix-core `flake.lock` pins onixpkgs at `de18d43acc410a38a2d5eee1e1c5dd8648b4db4e`.

# Evaluation

- Darwin toplevel derivation (evaluated on aspen3 with the flake's Nickel
  profile data; a prebuilt evaluator stood in for the eval-time wasm plugin,
  which is not part of the system closure):
  `/nix/store/v06nk4r74bf767pfrha2vjkzb01gjmgh-darwin-system-26.11.bb0b90d.drv`
- Built system: `/nix/store/jjygp79jpxr4dm7wlb9rr807islrippd-darwin-system-26.11.bb0b90d`
- Activated with `nix-env -p /nix/var/nix/profiles/system --set` and
  `<system>/activate` as root.
