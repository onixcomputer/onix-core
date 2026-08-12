## Why

The repository has reusable DGX Spark support, but no DGX machine owns that tag. Clan still owns the current machine inventory and deployment path.

The experimental Devenv machines work adds a useful DGX control surface. It evaluates NixOS machines and provides machine information, build, deploy, and install commands.

Pull request [cachix/devenv#3073](https://github.com/cachix/devenv/pull/3073) is still open and experimental. The repository needs an isolated pin, compatibility gates, and a clear rollback boundary.

## What Changes

- Pin the Devenv machines implementation at commit `6e61f6a12f730b81228f70ee2487320fdbb1e2fc` as a separate canary input.
- Keep the existing Devenv development shell on its current input until the canary passes its compatibility gates.
- Define DGX machine records in typed Nickel and lower them to the Devenv `machines.<name>` interface.
- Make Devenv the only lifecycle owner for declared DGX machines.
- Extract reusable NixOS cores for the DGX account, access, Tailscale, Sendme, iroh-ssh, and Mesh-LLM behavior.
- Add a repository command that exposes device-free `info` and `build` operations only.
- Reject incomplete hardware, storage, target, host-key, access-key, and secret records.
- Add positive and negative checks for evaluation, package closure, ownership, access, service parity, and destructive-command rejection.

## Impact

- **Files**: flake inputs and outputs, Devenv project files, typed inventory, generated inventory data, DGX modules, service modules, checks, and documentation.
- **Risk**: The upstream interface can change before merge. A separate exact pin limits this risk.
- **Non-goals**: Do not install, deploy, connect to, reboot, repartition, or modify a DGX machine in this change.
- **Non-goals**: Do not invent machine names, target hosts, disk paths, hardware reports, or host keys.
- **Testing**: Use synthetic fixtures and device-free Nix evaluation and builds. No check can open SSH connections to a target.
