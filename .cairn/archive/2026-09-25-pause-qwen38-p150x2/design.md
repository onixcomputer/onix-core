# Design: Pause the Qwen P150x2 service

## Context

`hardware.tenstorrent.qwen38` in the pinned tenstorrent.nix module defines
`qwen38-p150x2.service` with a fixed `wantedBy = [ "multi-user.target" ]`. The
module has no option to turn off the start. On `britton-desktop`,
`mesh-llm-mesh-llm-private-inference.service` and its research HTTP companion
list the unit in `Wants=`.

NixOS activation starts active targets again, and that brings back every
wanted unit that is not running. A manual `systemctl stop` therefore lasts
only until the next deployment or boot.

## Decisions

### Decision: Mask the unit instead of disabling the module

**Choice:** Set `systemd.services.qwen38-p150x2.enable = false` on
`britton-desktop`. Leave `hardware.tenstorrent.qwen38` enabled.

**Rationale:** A masked unit links to `/dev/null`, so no target, `Wants=`, or
manual start can run it. Dropping only `wantedBy` would still let mesh-llm's
`Wants=` start it at boot. Disabling the module would delete the unit
definition and the check's contract assertions with it. Masking keeps the
reviewed definition, and deleting one line restores the service.

### Decision: The check pins the pause

**Choice:** Replace the machine check's "starts through `multi-user.target`"
assertion with "is masked". Keep every other assertion about the unit.

**Rationale:** The check now fails if the unit is unmasked without a change
record, and it still guards the command, environment, devices, and conflicts
that a restore would bring back.

## Risks / Trade-offs

- mesh-llm private inference on this host has no local backend while the
  pause lasts. It already ran without one whenever Qwen was stopped by hand.
- `ttwkv7-owner-control restore` fails while the unit is masked. `validate`
  and `isolate` are unaffected.
- Restoring the service needs a deployment. A runtime `systemctl unmask`
  cannot remove a mask that NixOS generated.
