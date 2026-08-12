# Design: Repair the Aspen remote-builder route

## Context

The machine inventory stores `10.10.10.1` as Aspen's LAN address. The remote-builder module always prefers that field.

The desktop has no route to this cluster-only address. It can reach Aspen through `aspen1.local`.

## Design

### Typed configuration core

Move the builder-target contract to a reusable Nickel file. Add an optional, non-empty `sshHost` field.

Set Aspen's `sshHost` to `aspen1.local`. Keep its machine address unchanged.

### Pure endpoint selection

Select each builder endpoint with this order:

1. The target's explicit `sshHost`.
2. The machine's LAN address.
3. The machine name.

This function is deterministic and has no I/O.

### Imperative shell

Nix continues to create `nix.buildMachines` and SSH known-host entries. It performs no network probe during evaluation.

### Host-key binding

Add the explicit builder endpoint to Aspen's existing known-host aliases. This binds the route to the managed Aspen host key.

### Validation

The positive check requires `britton-desktop` to select `aspen1.local`. It also rejects the stale `10.10.10.1` builder endpoint.

The negative Nickel fixture uses an empty `sshHost`. Contract evaluation must reject it.

After deployment, one uncached derivation must execute on Aspen through `ssh-ng`.

## Safety

The change does not modify cluster links, SSH identities, or builder capacity. A missing explicit endpoint retains the old fallback behavior.
