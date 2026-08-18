## Why

The static-server schema defaults `isPublic` to false and labels that mode "PRIVATE (Tailscale Only)", but the module always binds a wildcard address and unconditionally opens the service port on every firewall interface. The deployed `static-server-demo` therefore does not enforce the access policy its inventory and generated page advertise.

## What Changes

- Make `isPublic` control firewall exposure and the permitted bind/access path.
- Restrict private instances to loopback or the Tailscale interface instead of globally opening their ports.
- Preserve explicit public exposure for `isPublic = true` instances.
- Add module-evaluation and VM coverage for both private and public modes.

## Impact

- **Files**: `modules/static-server/schema.ncl`, `modules/static-server/default.nix`, static-server inventory, and focused checks.
- **Risk**: Clients currently reaching a private instance over an unintended LAN path will stop working.
- **Non-goals**: Do not redesign Tailscale-Traefik routing or add application-layer authentication.
- **Testing**: Assert private firewall interface scoping, public global exposure, loopback reachability, and denial from a non-Tailscale peer.
