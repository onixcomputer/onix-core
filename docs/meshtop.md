# Meshtop on Aspen3, britton-desktop, Bonsai, and Leviathan

`meshtop` is the read-only, paired Iroh terminal monitor for these four
enrolled machines. The standalone `meshtop` repository owns the protocol and
UI; onix-core owns the pinned package, selected host/user services, desktop
roster, and rollout.
The imported source is commit `42f908b2e4d470c7ba45efaab8cb8a75bddb4292`.
`scripts/sync-meshtop.sh` admits only that clean revision and copies its Cargo
sources and lockfile into `pkgs/meshtop/source`. `nix build .#meshtop` builds from
that snapshot, not from the sibling checkout.

## Installed state

- Aspen3: the activated NixOS generation runs the enabled `meshtop.service` as a
  dynamic user. Its private, persistent key is `/var/lib/meshtop/agent.key`
  (0600); its observed public endpoint ID is
  `1513e39997fc37845f7af6421fdf1ebc47c3920123d66bd3849b934204c40339`.
- Bonsai: its machine configuration explicitly imports and enables the
  NixOS Meshtop module. The generated unit is running from a scoped
  `/etc/systemd/system.control` link backed by
  `/nix/var/nix/gcroots/meshtop-agent`, not a whole-system switch. Its own
  private key is `/var/lib/meshtop/agent.key` (0600), with observed public ID
  `9c71e0f64c3d068d9f6997a978d9575ca99486332ebec799b566a086b6520d66`.
- britton-desktop: the selected Home Manager profile declares an enabled
  `meshtop.service` user unit, the binary, and the four-host roster. The rendered
  unit, roster and onix-core package were installed individually rather than
  switching the entire NixOS generation; the service is enabled under the
  already-lingering `brittonr` user manager. Its separately keyed agent lives
  at `~/.local/state/meshtop/agent.key` (0600), with observed ID
  `6751880624ae32a6dddb262599be7a867fa20994ebcebb1d0e84c4b2aa0cfc77`.
  The Nix profile supplies `meshtop` on the desktop PATH. GC roots at
  `~/.local/state/meshtop/onix-{unit,roster}` retain the rendered service and
  roster until a normal Home Manager generation takes over.
- Leviathan: this externally administered NixOS builder is not part of the
  onix-core machine inventory. Its `brittonr` user runs the explicit
  `inventory/home-profiles/brittonr/meshtop/leviathan-agent.service` unit with
  a locally built binary from the same committed Meshtop revision. Its distinct
  private key is `~/.local/state/meshtop/agent.key` (0600); its public ID is
  `0cc38af96ba5edcac062ed2f0f90dcf2581915154a36b37a1b41677d87a304ac`.
  The service is enabled and currently active, but `Linger=no`: it is **not**
  established as running after the last user session exits or after reboot.
- All four agents admit **only** the desktop viewer's public endpoint ID
  `e4595bca7f97787646d6da8b3eab21f02e88d56759b9ac73d3a2f05c3932af51`.
  Its 0600 private key remains at `~/.local/state/meshtop/viewer.key`. None of
  the five private keys is a Nix evaluation input or stored in this repository.

From britton-desktop, use:

```sh
meshtop watch --hosts-file ~/.config/meshtop/hosts.toml \
  --key ~/.local/state/meshtop/viewer.key
# JSON, nonzero if any pinned host could not be sampled:
meshtop watch --hosts-file ~/.config/meshtop/hosts.toml \
  --key ~/.local/state/meshtop/viewer.key --once
systemctl --user status meshtop.service
```

After rebuilding the pinned package with `nix build .#meshtop`, run
`nix profile upgrade meshtop` from this checkout to replace the desktop viewer.
The themed cards are viewer-side, but CPU and GPU **model names** require each
agent to run the new binary. Prefer normal NixOS system switches; the scoped
exact-unit host updates and desktop user-unit update are described below.
None rotates a persistent identity or changes the authorized viewer. Until
an agent is updated, its CPU says "model unavailable" and a prior GPU label
may still say `AMD card0` or `AMD card1`; the older GPU telemetry boundary
remains explicit.

Leviathan's locally installed binary is not replaced by `nix profile upgrade`;
rebuild its selected source revision separately whenever this pin changes.

The CPU model is the agent host's reported brand. AMD GPU labels come from
each DRM card's read-only udev PCI model entry at agent startup, bounded and
sanitized before transmission. If unavailable, a numeric PCI vendor/device
ID (or an explicit unknown model) replaces the generic card label. PCI model
entries can list several possible retail GPU names for one device ID; Meshtop
does not guess a more specific SKU. Counters still cover AMD amdgpu's
read-only DRM sysfs only: the first discovered GPU per host shows busy
percentage and VRAM use, plus temperature and clock when available. Missing
counters stay missing; a measured `0%` means idle. NVIDIA and Tenstorrent
accelerators are not GPU telemetry sources in this revision.

An authenticated four-host sample showed these reported CPU brands and AMD
PCI-model labels (the PCI entries are not unique retail-SKU attestations):

| Host | CPU brand | AMD GPU PCI model or counter availability |
| --- | --- | --- |
| Aspen3 | `AMD RYZEN AI MAX+ 395 w/ Radeon 8060S` | `AMD Strix Halo [Radeon Graphics / Radeon 8050S Graphics / Radeon 8060S Graphics]` |
| britton-desktop | `AMD Ryzen 9 9950X3D 16-Core Processor` | `AMD Granite Ridge [Radeon Graphics]` |
| Bonsai | `AMD Ryzen AI 9 HX 370 w/ Radeon 890M` | `AMD Strix [Radeon 880M / 890M]` |
| Leviathan | `AMD EPYC 7763 64-Core Processor` | `GPU counters unavailable` (no supported AMD counters in the sample) |

Short TUI panels keep the CPU brand and utilization together on one line,
truncating the name before the percentage/meter. Long AMD model names also
truncate before the GPU busy percentage/meter rather than hiding the counter.
Taller panels show separate model rows. This is reported hardware inventory,
not independent PCI or host-identity attestation.

The TUI shows all four pinned hosts in separate live panels; no host selection
is needed. On terminals too small to display every panel, `j`/`k` or ↑/↓
scroll rows, Tab/PageDown advances a page, PageUp goes back, and `q` exits.
The roster pins public agent IDs, not DNS names or private keys. Rotating the
viewer key requires changing its ID on **all four** agents; rotating one
agent key requires changing only that host's roster ID. Do not copy an agent
key between machines.

On britton-desktop, `loginctl show-user brittonr -p Linger` reported
`Linger=yes`; logout/reboot continuity was not exercised in this rollout.

On Aspen3, inspect `systemctl status meshtop.service` and
`journalctl -u meshtop.service`; neither command needs to print its private
key. The observed online Tailnet peer during rollout was `aspen3-1` at
`100.108.13.4`; `aspen3` at `100.111.69.107` was an offline stale peer. Choose
the currently online peer from `tailscale status` rather than assuming either
IP stays assigned. `stat -L -c '%a %U' /var/lib/meshtop/agent.key` reported
`600 nobody`, consistent with systemd's private DynamicUser state mapping.

## Deployment and evidence boundary

### Current hardware-model source pin

For source `42f908b2e4d470c7ba45efaab8cb8a75bddb4292`, `nix build .#meshtop`
produced
`/nix/store/xm1622ay07qcdpn9k71lk2yp3b63jdxn-meshtop-0.1.0`.
Both generated NixOS units built to
`/nix/store/2gy42kr0nmr5ff3p2v0kv3iganj1bm2s-unit-meshtop.service`;
the Home Manager user unit built to
`/nix/store/svh5j0yrcd1nj1q6rcvkj7qhc3nv87ls-meshtop.service`.
These are Meshtop-scoped outputs, not new whole-system generations. The
Aspen3/Bonsai exact-unit closures were copied over authenticated strict-SSH
routes; both `system.control` service links, Meshtop services and permanent
GC roots (`meshtop-gpu-agent` on Aspen3, `meshtop-agent` on Bonsai) select
this generated unit. The desktop user-service link and `onix-unit` GC root
select its generated Home Manager unit, and its Nix profile viewer resolves
to the package above. All three original services reported `active` with the final
package in `ExecStart`; existing viewer and agent keys and public IDs were
retained. No full system/Home Manager generation was switched or rebooted.

An authenticated `watch --once` from that original rollout returned all three
pinned endpoint IDs, the CPU/GPU model names in the table above, and live
CPU/GPU percentages. At 74×38 terminal cells the actual dashboard showed
`3/3 live`, CPU model names and utilization, and AMD GPU model and busy
meter on each card. Aspen3's long PCI candidate list ended with `…` so its
observed `0%` busy meter remained visible; `j` scrolled to Bonsai's
`Radeon 890M` CPU brand and `0%` AMD GPU row. This observes only the
selected agents, snapshot and terminal; reboot continuity remains untested.

### Leviathan scoped enrollment

Leviathan is an operator-controlled NixOS builder reached as
`brittonr@leviathan.cymric-daggertooth.ts.net` over strict SSH, not a machine
declared in onix-core's core inventory. Its user is not authorized to import
the unsigned onix-core Nix store closure: `nix copy --to ssh-ng://...`
refused the Meshtop package for lack of a trusted signature. Instead, its
user cloned `https://github.com/brittonr/mtop.git`, checked the exact
`42f908b2e4d470c7ba45efaab8cb8a75bddb4292` commit. From that source
checkout on Leviathan, the selected build and install are:

```sh
nix shell nixpkgs#rustc nixpkgs#cargo nixpkgs#gcc \
  --command cargo build --release --locked
install -D -m 0755 target/release/meshtop ~/.local/bin/meshtop
```

Its source remains at `~/.local/src/meshtop`. The GCC shell supplies Cargo's C
linker. No unsigned store import or whole-system switch was performed.

The repo-owned
`inventory/home-profiles/brittonr/meshtop/leviathan-agent.service` is installed
at Leviathan's `~/.config/systemd/user/meshtop.service`, enabled under
`default.target`, and runs as the `brittonr` user. Its separate, on-host 0600
agent key is never copied to the desktop; it admits only the existing
desktop viewer. The desktop Home Manager-generated four-host roster is
`/nix/store/wdca2qz37gin8cprz2cfk4gxz6xx2z4k-hm_.configmeshtophosts.toml`,
retained by `~/.local/state/meshtop/onix-roster` and linked as
`~/.config/meshtop/hosts.toml`. The three original endpoint IDs and both
existing desktop keys remain unchanged.

The authorized viewer returned four current `watch --once` snapshots with
the original three IDs and Leviathan's new ID. At 74×38 terminal cells the
actual dashboard showed `4/4 live`; Tab moved from Aspen3/desktop to
Bonsai/Leviathan. Leviathan reported `AMD EPYC 7763 64-Core Processor`,
CPU/memory/network/disk/process values, and `GPU counters unavailable`.
This is not a claim of NVIDIA, Tenstorrent, or other non-amdgpu telemetry.

An isolated, new unpaired viewer identity returned only a `reading snapshot`
error and exit status 1 for Leviathan, with no telemetry.

**Session-only boundary:** Leviathan reports `Linger=no`. Running
`loginctl enable-linger brittonr` as the user returned `Access denied`;
noninteractive sudo and root SSH were also denied. Other user sessions
kept the agent active during the four-host sample, but its user manager
may stop when the last session exits and is not assured to start at boot.
The operator accepted this session-only availability for the four-host
dashboard; it is not a persistent boot service.

An authorized Leviathan administrator must run
`sudo loginctl enable-linger brittonr`, then verify `Linger=yes`, the
enabled user unit and a fresh four-host authenticated sample. Do not claim
logout or reboot continuity before that check. Onix-core maintains the
roster and user-unit template; Leviathan's owner maintains its local
binary and user-manager lifecycle.

The following system-switch and GPU-only source-pin details record earlier
rollout history for the original three hosts. Use their **current** source
pin and exact generated units above, and Leviathan's selected user unit, for
the installed hardware-name behavior.

The Aspen3 system closure built locally, then Clan copied and activated it with
`clan machines update aspen3 --target-host root@100.108.13.4 --build-host
localhost --host-key-check strict` from the onix-core `.#minimal` shell. Building
on Aspen3 itself failed during Nickel Wasm evaluation (`unexpected EOF`), so
`--build-host localhost` matters on this route. Clan observed the new
`/run/current-system`, enabled and started `meshtop.service`. Its first
activation reported pre-existing `celld-site-storage-provision.service` and
`celld.service` failures; a retry found the new system already active. Those
failures are not Meshtop readiness claims.

For another Aspen3 rollout, from the onix-core checkout, use the currently
online peer address and the minimal Clan shell:

```sh
NIX_CONFIG=$'min-free = 0\nmax-free = 0\nconnect-timeout = 1\ndownload-attempts = 1' \
  nix develop --accept-flake-config .#minimal -c clan machines update aspen3 \
  --target-host root@100.108.13.4 --build-host localhost --host-key-check strict
```

### Scoped Aspen3 GPU update

The GPU-source refresh did **not** complete another full Aspen3 NixOS switch:
two local full-closure/Clan builds reached 3600-second command deadlines while
compiling unrelated locked packages. The previous system generation is still
current. Instead, the exact unit generated by that system configuration was
built separately from the onix-core checkout:

```sh
nix build --impure --no-link --print-out-paths --expr \
  '(builtins.getFlake (toString ./.)).nixosConfigurations.aspen3.config.systemd.units."meshtop.service".unit'
```

For the preceding GPU-only source pin, this build returned
`/nix/store/4gzrcx4rkmkk33ddxz2zg65x8hr270d2-unit-meshtop.service`.
The generated unit still has the declared DynamicUser sandbox, viewer ID, and
key path; its `ExecStart` uses the new Meshtop package. Nix copied its two-path
closure through the authenticated Tailnet SSH route to Aspen3. That earlier
unit was pinned by `/nix/var/nix/gcroots/meshtop-gpu-agent`; the symlink at
`/etc/systemd/system.control/meshtop.service` pointed to its service file.
Systemd's persistent `system.control` load path has priority over the older
read-only `/etc/systemd/system` unit. `daemon-reload` and a Meshtop-only restart
selected the new `ExecStart`. No other Aspen3 service or system generation was
activated by this update; reboot continuity has not been exercised. Remote
Nix ran auto-GC during the transfer, so retain the scoped GC root.

On a later source update, rebuild this *generated unit*, copy its store
closure through the currently authenticated Tailnet SSH route, update only its
GC root and `system.control` link, reload/restart Meshtop, then check both
`FragmentPath`/`ExecStart` and an authenticated two-host `watch --once`.
On the next successful full Clan system switch, remove the scoped link,
reload/restart, confirm the managed unit runs the intended new package, and
only then remove its extra GC root. The scoped link otherwise continues to
override newer NixOS generations; onix-core owns this cleanup.

### Scoped Bonsai enrollment

`machines/bonsai/configuration.nix` explicitly imports `modules/meshtop` and
enables its agent with the existing desktop viewer ID. The other inventory
machines do not inherit this opt-in. Of the 12 declared core machines and no
additional DGX-generated machines, strict noninteractive SSH from the desktop
reached Bonsai, Aspen3, and britton-desktop. britton-fw timed out; aspen1
timed out over `.local`, RDMA, and Tailnet; aspen2's hostname was unreachable
and its RDMA/Tailnet routes timed out; pine and utm-vm did not resolve; the
three `chv-dev` VM IPs had no route; britton-air's inventory IP had no route
and its `.local` name did not resolve. These are selected-route observations,
not evidence that the excluded machines can never be reached.

No whole Bonsai system generation was switched. From this checkout, build
only its exact generated unit:

```sh
nix build --impure --no-link --print-out-paths --expr \
  '(builtins.getFlake (toString ./.)).nixosConfigurations.bonsai.config.systemd.units."meshtop.service".unit'
```

For the preceding GPU-only source pin the result was the same
`/nix/store/4gzrcx4rkmkk33ddxz2zg65x8hr270d2-unit-meshtop.service` as
Aspen3: the policy, viewer and package were identical, but **not** the private
agent identities. The exact store closure was copied to
`ssh-ng://root@100.126.162.16` after strict host-key SSH verification. On
Bonsai, `/nix/var/nix/gcroots/meshtop-agent` pinned that earlier unit;
`/etc/systemd/system.control/meshtop.service` pointed to its service file.
An additional link at
`/etc/systemd/system.control/multi-user.target.wants/meshtop.service`
pulls the service into `multi-user.target` on the writable persistent
systemd path. After `daemon-reload` and starting only Meshtop, `FragmentPath`
resolved to the scoped link, `ExecStart` selected the pinned Meshtop binary,
and `systemctl show -p Wants multi-user.target` listed `meshtop.service`.
`systemctl is-enabled meshtop.service` still reports `disabled` because
the boot-target link is outside the conventional `/etc/systemd/system` path;
the target dependency was observed, but reboot continuity was not exercised.
The on-host generated 0600 key and public ID are listed above.

For a new Bonsai source pin, build and copy its generated unit, replace only
the scoped GC root and `system.control` links, reload/restart Meshtop and
verify its `FragmentPath`, viewer policy, stable public ID and an authenticated
sample. On the next successful full Clan switch, remove **both** scoped
system.control links, reload/restart, verify the managed unit and authenticated
sample, then remove the extra GC root. Until then, onix-core owns these
links and the explicit machine option.

The desktop's **whole NixOS closure was not switched**. The retained lockfile
pins `tenstorrent.nix`/TT-Metal 0.77.0, whose bundled ELFIO 3.12 header uses
`uint16_t` without including `<cstdint>` under GCC 16. That unrelated C++
build stops the full desktop system; `/etc/systemd/system` is read-only, so a
manual system-unit installation is not a safe substitute. Instead, the exact
unit and roster generated from `inventory/home-profiles/brittonr/meshtop` were
linked into the writable user systemd/config directories, backed by the GC
roots above. `nix profile add .#meshtop` installed the onix-core viewer. The
Home Manager generation with both hosts builds, but running its entire
activation would change unrelated desktop profile state. Repair TT-Metal in
its owning package repository and review the complete desktop closure before
a normal Clan system switch. That switch can adopt the already-declared
Home Manager service; retire the temporary GC roots and redundant Nix-profile
entry only after confirming the new generation owns the running unit.

The separate TT-Metal fetch-queue diagnostic runtime uses an onix-core
instrumentation-patch rebase for this locked revision; the production runtime
is unchanged. That patch does not repair ELFIO's missing include.

For a fresh, targeted desktop installation from the onix-core checkout, keep
the already-paired viewer key; a newly generated viewer key will not match
the four pinned agent policies. These evaluated Home Manager outputs can be
installed without activating unrelated profile files:

```sh
nix build --impure --out-link ~/.local/state/meshtop/onix-unit --expr \
  'builtins.dirOf (builtins.getFlake (toString ./.)).nixosConfigurations."britton-desktop".config.home-manager.users.brittonr.home.file."/home/brittonr/.config/systemd/user/meshtop.service".source'
nix build --impure --out-link ~/.local/state/meshtop/onix-roster --expr \
  '(builtins.getFlake (toString ./.)).nixosConfigurations."britton-desktop".config.home-manager.users.brittonr.home.file.".config/meshtop/hosts.toml".source'
nix profile add .#meshtop
systemctl --user link "$(readlink -f ~/.local/state/meshtop/onix-unit/meshtop.service)"
install -d -m 0700 ~/.config/meshtop
ln -s "$(readlink -f ~/.local/state/meshtop/onix-roster)" ~/.config/meshtop/hosts.toml
systemctl --user enable --now meshtop.service
```

For a GPU-capable desktop agent update, keep the existing roster and private
keys. Rebuild only its Home Manager-generated unit, replace the existing
Meshtop user-unit link, and restart that unit; do not activate the unrelated
desktop profile:

```sh
nix build --impure --out-link ~/.local/state/meshtop/onix-unit --expr \
  'builtins.dirOf (builtins.getFlake (toString ./.)).nixosConfigurations."britton-desktop".config.home-manager.users.brittonr.home.file."/home/brittonr/.config/systemd/user/meshtop.service".source'
ln -sfn "$(readlink -f ~/.local/state/meshtop/onix-unit/meshtop.service)" \
  ~/.config/systemd/user/meshtop.service
systemctl --user daemon-reload
systemctl --user restart meshtop.service
```

The `onix-unit` GC root retains the new unit and binary. Confirm its new
`ExecStart` with `systemctl --user cat meshtop.service` and request a new
snapshot before treating displayed GPU counters as live.

To change roster membership without changing the desktop agent or viewer
keys, build the Home Manager roster output from this checkout, update its
existing GC root and replace only the viewer's hosts-file symlink:

```sh
nix build --impure --out-link ~/.local/state/meshtop/onix-roster --expr \
  '(builtins.getFlake (toString ./.)).nixosConfigurations."britton-desktop".config.home-manager.users.brittonr.home.file.".config/meshtop/hosts.toml".source'
ln -sfn "$(readlink -f ~/.local/state/meshtop/onix-roster)" \
  ~/.config/meshtop/hosts.toml
meshtop watch --hosts-file ~/.config/meshtop/hosts.toml \
  --key ~/.local/state/meshtop/viewer.key --once
```

Only change the roster link when membership or an agent ID intentionally
changes. An agent refresh retains the existing public IDs and all private
key files.

The pre-existing `flake.lock` edits were retained. The locked Nixpkgs marks
`radicle-node-1.10.3` insecure because its private-repository traffic is not
encrypted or authenticated. The flake's `radicle-node` package permits exactly
that version for every Radicle host (`.cairn/changes/permit-insecure-radicle-node`);
it is not a global Nixpkgs allowance or a security fix. It does not change
Meshtop's authenticated telemetry boundary.

The initial two-host rollout observed `watch --once` returning live CPU,
memory, disks, and processes for **both** initially pinned hosts; both were
`ON` in the TUI. An
unpaired viewer key failed with no snapshot for either host. With only the
desktop agent stopped, Aspen3 still returned a current snapshot; the desktop
returned `dial timed out`. The user unit was restarted afterward. Both agent
IDs stayed fixed across service restarts; the desktop viewer received a fresh
Aspen3 sample after its restart.

The upgraded onix-core viewer's `watch --once` again sampled both agents. At
120×30 and 80×24 its TUI showed separate `ON` cards for Aspen3 and
britton-desktop simultaneously, each with its own CPU, memory, network, disks,
and top processes; neither required switching selection.

For the GPU update, the older agents returned `gpus: null`, while the
refreshed desktop user unit and scoped Aspen3 system unit retained both roster
IDs and reported `AMD card0` and `AMD card1` respectively. An authenticated
`watch --once` observed Aspen3 at 0% busy (a measured idle value), 1.2 GiB /
4.0 GiB VRAM, 42°C, and 602 MHz; the desktop returned 5% busy, 60.8 MiB /
2.0 GiB VRAM, 67°C, and 2200 MHz. The installed TUI displayed CPU history,
memory, both GPUs, network, filesystems, and processes concurrently at 120×30
and 80×24. These are selected live samples, not vendor-wide GPU coverage.

For the Bonsai enrollment, the Home Manager-rendered three-host roster
retained Aspen3's and britton-desktop's IDs and pinned Bonsai's observed
public ID. A single authorized `watch --once` returned current CPU, memory,
AMD GPU (`card1` on Bonsai), network, disks and processes from **all three**
agents. A temporary, unrelated viewer identity could not fetch Bonsai's
telemetry (`dial failed`, no snapshot). A 140×52 terminal showed all three
live panels; at 80×24, the first viewport showed Aspen3 and desktop at `ON`,
`j` revealed Bonsai at `ON` in viewport 3–3/3, and `k` returned to the
still-live initial two panels.

Stopping only Bonsai's service left the first two TUI panels `ON` with
current observations while its own card became `OFF`, displayed `dial timed
out`, and retained the last known metrics. With a sole viewer process,
`watch --once` returned two current snapshots and a Bonsai `dial timed out`
error with nonzero exit. Restarting only Bonsai restored its `ON` panel and
the same pinned identity. A simultaneous TUI and `watch --once` with the
**same** viewer key instead produced `dial failed` for healthy hosts in the
one-shot process; closing the TUI restored a successful three-host one-shot
sample. Use one active viewer process per viewer identity for these checks;
the cause of that concurrent-dial observation has not been established.

These observations establish the selected routes at the time of the check,
not arbitrary WAN reachability, host health, or all other services.
Iroh's default DNS/relay infrastructure can observe routing metadata but not
the authenticated QUIC telemetry payload. Paired telemetry includes process
**names** and mount paths; protect the viewer key and terminal output. No
remote command, process arguments, or Tile authority is exposed.

Cairn policy validation found no issues. Active-change readiness reported
completion `unavailable`, with sync/archive blocked; this rollout does not
claim a lifecycle release or publication receipt.

To roll back only the scoped Aspen3 GPU update, remove
`/etc/systemd/system.control/meshtop.service`, reload systemd, and restart
`meshtop.service`; the previous NixOS-managed unit remains available. Verify
its `FragmentPath` and a sample before removing the scoped GC root. To stop
Meshtop entirely, disable the desktop user unit with `systemctl --user disable
--now meshtop.service`, or first remove Aspen3's scoped link and then disable
`services.meshtop.enable` through Clan. Neither action deletes a private agent
identity; delete a key only when revoking its ID and updating the roster.
Remove the desktop's separately linked unit and roster only after a managed
Home Manager generation takes over.

To remove only Bonsai, first remove its pinned ID from the desktop roster
and rebuild/relink that roster. Then stop `meshtop.service` on Bonsai, remove
its scoped `multi-user.target.wants/meshtop.service` and
`meshtop.service` links from `/etc/systemd/system.control`, and reload
systemd. Retire `/nix/var/nix/gcroots/meshtop-agent` only after no running
service references its binary. Disabling the machine option through a
normal Clan switch is the durable removal. Keep Bonsai's private seed unless
revoking its endpoint identity deliberately.
