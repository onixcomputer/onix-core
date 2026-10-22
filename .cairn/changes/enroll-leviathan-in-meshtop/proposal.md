# Enroll Leviathan in the paired Meshtop dashboard

## Why

Leviathan is an SSH-reachable, operator-controlled NixOS builder outside onix-core's machine inventory. The existing desktop viewer has no pinned endpoint for it, so the three-host dashboard cannot observe its CPU, memory, network, disks, or processes.

## What Changes

- Run Meshtop from the published, exact committed source under Leviathan's own user, with a new private key created only on that host and the existing desktop viewer ID as its sole authorization.
- Add the observed public agent ID to the desktop's Home Manager-generated roster without changing the three existing IDs, viewer key, or existing agent units. Ship a repo-owned, selected Leviathan user-unit template instead of enrolling the external machine in the core NixOS inventory or switching its generation.
- Exercise the authenticated four-host JSON and TUI views; record the current user-manager persistence limit and its required administrator action rather than claiming unsupported reboot continuity.

## Impact

- **Owners:** Meshtop owns its read-only protocol and counters; onix-core maintains the desktop roster and explicit Leviathan user-unit template; Leviathan's administrator owns user lingering and its host lifecycle.
- **Boundaries:** The on-host key never enters the repository, Nix evaluation, or the viewer machine. Leviathan reports an AMD EPYC CPU but no supported AMD GPU counters in the observed sample. `Linger=no` prevents a logout/boot-continuity claim without administrator authorization.
- **Verification:** Exact source revision and local release build on Leviathan, 0600 host key and unit state, rendered four-host roster, four authenticated snapshots, real TUI navigation, scoped repository checks and Cairn validation.
