## Why

The personal Radicle node under `/home/brittonr/.radicle` stopped after it received a termination signal. No user service restarted it.

The machine-scoped replica under `/var/lib/radicle` cannot replace the personal node. It uses a separate identity and authority boundary.

## What Changes

- Add a desktop-only Home Manager profile for the personal Radicle node.
- Run the existing isolated Radicle wrapper as a supervised user service.
- Restart the node after an unexpected clean termination.
- Start the service after the YubiKey agent.
- Enable user lingering so supervision survives logout and starts after boot.
- Keep the personal node on an operating-system-selected loopback port.
- Add positive and negative evaluation checks.

## Impact

- **Files**: desktop Home Manager inventory, a new personal Radicle profile, desktop user supervision, focused Home Manager checks, and lifecycle artifacts
- **Testing**: focused Home Manager evaluation, service-shape checks, desktop system evaluation, Cairn gates, and live user-service validation after deployment
