# meshtop

A read-only, btop-inspired terminal dashboard for explicitly paired systems. Each system runs a small sampler; one terminal connects to them over authenticated Iroh/QUIC. Every visible host gets its own colored panel with the CPU's reported brand, CPU history and per-core utilization, load, memory, swap, network rates, disk usage, uptime, top processes, reachability, and sample age. On Linux hosts with readable amdgpu DRM sysfs counters, the agent also reports GPU utilization, VRAM used/total, temperature, and clock speed. The GPU label comes from the host's PCI model database; if that model is unavailable, the card's numeric PCI ID is shown rather than an invented product name.

## Install

Build on each machine with a Rust toolchain (verified with Rust 1.97.1):

```sh
cargo install --path . --locked
```

From this workspace without an installed Rust toolchain, `nix shell nixpkgs#rustc nixpkgs#cargo --command cargo build --locked` builds the binary. Run commands from this repository (`meshtop/`), not the parent sibling workspace.

## Pair systems

1. On the **viewer** machine, run `meshtop id`. Save the printed endpoint ID. This creates `~/.local/state/meshtop/viewer.key` if missing.
2. On **each monitored** machine, run `meshtop agent --viewer <VIEWER-ID>`. Save the `agent id` printed at startup; repeat this command under a service manager for persistent monitoring. Each agent uses its own `~/.local/state/meshtop/agent.key`.
3. On the viewer, start the dashboard with one entry per agent:

   ```sh
   meshtop watch --host desktop=<DESKTOP-AGENT-ID> --host server=<SERVER-AGENT-ID>
   ```

   Or store the roster in `hosts.toml`:

   ```toml
   [[hosts]]
   name = "desktop"
   id = "<DESKTOP-AGENT-ID>"

   [[hosts]]
   name = "server"
   id = "<SERVER-AGENT-ID>"
   ```

   Then run `meshtop watch --hosts-file hosts.toml`. `--host` entries may be combined with the file. The host label in the dashboard comes from this pinned roster, not from the agent's hostname.

The viewer identity and each agent identity are persistent 32-byte secrets, stored in separate owner-only 0600 files on Unix. Protect and back up these keys; do not copy one agent's key onto another machine. Changing the viewer key requires updating `--viewer` on every agent; changing an agent key requires updating its roster ID. The protocol does not automatically discover or enroll systems: only the configured roster is shown.

On a systemd user host, persist an agent with a unit at `~/.config/systemd/user/meshtop-agent.service` (replace the viewer ID and executable path):

```ini
[Unit]
Description=Read-only meshtop agent

[Service]
ExecStart=%h/.cargo/bin/meshtop agent --viewer <VIEWER-ID>
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
```

Run `systemctl --user daemon-reload && systemctl --user enable --now meshtop-agent.service`. Keeping user services running after logout requires the host's user-lingering policy; the unit does not change that policy. For private routing, add `--direct-only --bind <LOCAL-IP:PORT>` to `ExecStart` and configure the corresponding pinned address in the roster.

### Direct-only / private network

Default Iroh configuration uses Number 0's DNS address lookup and relays when needed. For a private network, both sides can disable discovery and public relays. Give the agent a UDP listening address and provide its reachable address to the viewer:

```sh
# Monitored machine (open the chosen UDP port in its firewall):
meshtop agent --viewer <VIEWER-ID> --direct-only --bind 0.0.0.0:4242
# Viewer machine (use the agent ID and its real reachable IP):
meshtop watch --direct-only --host 'server=<SERVER-AGENT-ID>@192.0.2.10:4242'
```

For a roster file, add `address = "192.0.2.10:4242"` to every `[[hosts]]` entry. `--direct-only` rejects hosts without explicit addresses. For a same-machine test, use agent `--bind 127.0.0.1:0` and copy its printed `direct address:` into the `@IP:PORT` suffix. Direct-only requires IP reachability; it does not traverse NAT or establish VPN connectivity on its own.

### Controls and scripted sample

Hosts appear together in a responsive grid instead of requiring selection. Colored CPU, memory, VRAM, and disk meters make the same per-host values easier to scan; textual status and sample age remain visible without color. If the terminal cannot fit every panel, `j`/`k` or the arrow keys scroll by row; Tab/PageDown and PageUp page through the grid. `q`/Esc exits and restores the terminal. Green `ON` is a recent snapshot, yellow `STALE` means no successful update in 10 seconds, red `OFF` means the last request failed. The last successful sample remains visible with an error and its age; errors are never presented as current readings. A viewer connected to an older agent explicitly says GPU telemetry was not reported, rather than inventing an idle reading.

CPU and GPU model labels stay visible in compact cards. A short CPU card keeps
the reported model and utilization on the same line, truncating the name before
the percentage and meter; long GPU labels also truncate before their busy
percentage and meter. Taller cards show separate model rows.

`meshtop watch --hosts-file hosts.toml --once` fetches one sample per system, prints JSON, and exits nonzero if any configured host fails. Use `--once` for scripts and non-interactive terminals. CPU and process percentages need a sampling interval; the agent warms up before its first reply. Network rates require two successful polls, so they are zero in a one-shot sample.

## Scope and security

- The agent admits only its configured viewer's authenticated Iroh endpoint ID. The viewer pins every agent ID. An ID is not a hostname, and a reachable relay does not grant telemetry access. One viewer connection is served at a time.
- The wire protocol has a versioned ALPN, one-byte read-only request, a 64 KiB bounded JSON response, and deadlines. No remote command, process arguments, environment variables, usernames, input injection, or host-control endpoint exists. Process **names**, mount paths, and CPU/GPU model names are visible to the paired viewer; treat the viewer key and dashboard as sensitive.
- Collection is capped at 256 CPU cores, 32 nonzero disks, 64 top processes, and 8 AMD GPUs per sample; up to 64 configured hosts. GPU discovery inspects at most 128 DRM entries at agent startup. AMD counters are read from bounded, read-only sysfs files; their names come from a bounded, read-only udev PCI entry looked up once per GPU. Missing or inaccessible counters are unavailable, never interpreted as zero. Non-amdgpu devices (including Tenstorrent accelerators) are not GPU telemetry sources for this monitor. Each viewer reconnects after failures. A connection failure can still mean local routing, DNS, relay, firewall, host sleep, or network problems; it is not a health diagnosis.
- Default Iroh DNS and relays are third-party connectivity dependencies and can observe routing metadata, not the authenticated QUIC sample payload. Direct-only avoids those dependencies but requires reachable UDP addresses.
- This repository owns the monitor and its maintenance. It does not add Tile workspace telemetry or claim deployment/readiness on arbitrary networks. Repeatability: `cargo test --locked` includes a real local Iroh authorization/snapshot exchange; `watch --once` can exercise two separately keyed local agents. Neither proves WAN/relay availability or arbitrary-host correctness.
