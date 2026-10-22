## Decision

Keep the typed static SSH policy in `ssh.ncl` and generate changing Tailscale addresses at runtime. The base profile automatically loads the focused updater module; `ssh.nix` includes `~/.ssh/tailscale_hosts` from its final all-host context. OpenSSH's first-value precedence preserves earlier explicit routes, usernames, identities, and host-key aliases.

## Discovery and persistence

The packaged stdlib-only Python CLI reads one bounded `tailscale status --json` response from the local daemon. It requires a running backend and a structurally complete inventory, includes Self and all Peer entries, and does not filter offline devices. Assigned `DNSName` values are validated, normalized, and used for aliases; raw device HostName values are not SSH syntax. Unique short names and full DNS names target validated IPv4 addresses, matching the existing `AddressFamily inet` policy. Ambiguous short names are omitted while their full aliases remain available.

A successful refresh replaces the user-owned file atomically at mode 0600; unchanged contents do not require rewriting. Status, parse, validation, or write failures leave the prior good file intact. A valid inventory with no peers removes disappeared peers rather than retaining stale rows indefinitely.

## Scheduling and activation

The Home Manager profile packages the executable with pinned Python and Tailscale binaries. On Tailscale-enabled Linux hosts a user oneshot service is scheduled five seconds after user-manager startup and every minute thereafter. The generated file is runtime state, not a Home Manager symlink or an impure Nix input.

The authoritative checkout contains unrelated dirty deployment work. Build the selected SSH config and updater units from the source without switching the complete NixOS or Home Manager generation. Keep a user-owned Nix GC root for selected artifacts, retain the previous SSH config for rollback, and activate only the SSH config, executable and scheduler on Britton and Aspen3. Subsequent normal onix-core deployments retain the same feature through the source profile.

## Risks and verification

- Discovery can only list devices visible to the local Tailscale identity. It neither broadens ACLs nor discovers correct remote Unix usernames.
- Offline devices may not be SSH-capable; listing them is not a reachability claim.
- Static routing overrides still win. Remove stale copied Tailscale HostName values, not intentional aspen3 root/LAN routing or Git host policy.
- Verify consumer behavior with actual `ssh -G`, real local inventories and updater execution. Exercise offline retention, DNS ambiguity/injection, failed refresh preservation, successful removal, unchanged writes, and scheduler activation with isolated regressions and live observations.

## Observed scoped deployment

On 2026-10-14 the source-derived updater, SSH config and user units were built with the checkout's locked nixpkgs/Home Manager inputs and the already installed compatible Wasm parser, using a standalone evaluation of the SSH profile modules. Full-machine evaluation was stopped when it attempted unrelated Rust parser builds. Standalone assertions passed; no whole-system or Home Manager generation was activated.

Both hosts have enabled, active timers and successful service exits. Britton generated 570 visible-device entries and Aspen3 generated 35; this difference is intentional local-identity scope. Normal `ssh -G` retained aspen3's root/LAN/HostKeyAlias policy and Git's username, and selected `100.117.237.102` for britton-gpd, distinct from Bonsai's `100.126.162.16`. A strict-host-key SSH connection from Aspen3 to Britton succeeded using the generated routing.

The deployed Python file on both hosts matches the source SHA-256 `f22138c1dbbefe0ec7f4894ece1ade33f0f0fa515be1143f95273770125883e4`. Runtime refresh retained mode 0600, user ownership, and unchanged-file inode/mtime. The package and rollback target are retained under `~/.local/state/tailscale-ssh-sync/`.

Selected SSH/unit links use a `*-home-manager-files` tree so future Home Manager activation accepts them. A persistent systemd control drop-in runs the restore helper as brittonr after the old generation's activation. Its guard accepts only the exact prior SSH config SHA-256 `ee173f18cb7c21072f29a42f0a6f39cf12177d1b8070f18dcfb41a3fbf902546`. Smoke execution restored that old config and left newer, custom and absent configs untouched. The hook is loaded on both hosts; no reboot or full activation was used as a test. Retire the drop-in and selected GC roots after the managed generation adopts the source feature.

Native Cairn validation succeeded with `valid: true` and no issues using the physical policy path `/home/brittonr/git/OnixResearch/cairn/cairn-policy/generated/cairn-policy.json`. The shorter checkout path is a symlink, which this CLI's policy loader rejects.
