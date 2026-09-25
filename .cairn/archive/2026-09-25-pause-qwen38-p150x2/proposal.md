## Why

The operator needs both P150 cards on `britton-desktop` free for Tenstorrent
work outside the managed service. `qwen38-p150x2.service` is wanted by
`multi-user.target`, and `mesh-llm-mesh-llm-private-inference.service` also
wants it. As a result, every boot and every deployment starts Qwen again and
takes both cards. On 2026-09-25 a manual stop at 07:53 was undone twice by
deployment activations.

## What Changes

- Mask `qwen38-p150x2.service` on `britton-desktop` until the operator
  restores it.
- Keep the unit's definition (package, mesh, loopback endpoint, limits) so
  that removing one line restores the service.
- Record the pause in the host Tenstorrent guide and in `AGENTS.md`.
- Update the machine check to require the mask in place of the boot-time
  start.

## Impact

- **Files**: `machines/britton-desktop/configuration.nix`,
  `flake-outputs/_machine-checks.nix`, `AGENTS.md`.
- **Risk**: the mesh-llm private inference node on `britton-desktop` has no
  local backend while the unit is masked. `ttwkv7-owner-control restore` and a
  manual `systemctl start` are refused.
- **Non-goals**: no change to the tenstorrent.nix module, to the mesh-llm
  inventory, or to any other machine.
- **Testing**: the machine check, an evaluation of the unit's `enable` value,
  a closure and unit comparison before activation, and, on the target, a
  masked load state, a refused start, and no process holding either P150
  device.

## Affected Specs

- `tenstorrent-vllm-serving`: the deployment requirement moves from a
  boot-time start to a masked unit.
