# Repair the Aspen remote-builder route

## Why

`britton-desktop` sends Nix builder SSH traffic to `10.10.10.1`. That address is a private Aspen cluster link and is not routed from the desktop.

Aspen remains reachable at `aspen1.local`. The builder configuration needs a route that is separate from the machine's cluster address.

## Outcome

- Add a typed, optional SSH host to each builder target.
- Route the Aspen builder through `aspen1.local`.
- Preserve `10.10.10.1` for cluster traffic.
- Add positive and negative evaluation checks.
- Deploy and prove one remote Nix build.

## Non-goals

- Do not change Aspen cluster networking.
- Do not rotate SSH keys.
- Do not add a second remote builder.
