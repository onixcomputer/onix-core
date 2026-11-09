# OnixOS aspen2 pilot

aspen2 can be built by OnixOS as well as by Clan, from the same commit. Every Clan service that reaches aspen2 is a typed Nickel module, its secrets are OnixOS artifacts, and the host stays NixOS, built by OnixOS `mkFlake` with the Nix backend. Clan still builds and deploys aspen2: nothing here changes `nixosConfigurations.aspen2`. The Cairn change [`prepare-onixos-aspen2-pilot`](../.cairn/changes/prepare-onixos-aspen2-pilot/) records the decisions and the parity evidence.

## Layout

| Path | Contents |
|---|---|
| `flake-outputs/onixos.nix` | `mkFlake` call; exposes `onixos.nixosConfigurations.<machine>` for assembled machines |
| `onixos/inventory.ncl` | OnixOS inventory: machines projected from `inventory/core/machines.ncl`, instances from `onixos/instances/` |
| `onixos/services/<name>.ncl` | Typed Nickel service modules with tests |
| `onixos/services/<name>.nix` | Sidecars: upstream NixOS modules, overlays and modules a service must follow |
| `onixos/instances/<name>.ncl` | The Clan instances, with the same names and settings |
| `onixos/nix/` | Tag files, machine files and clan-core base defaults as NixOS modules; vars compatibility; package overlays; the check that every sops secret is encrypted to its machine |
| `onixos/secrets/` | Byte-identical copies of the deployed Clan vars files |
| `onixos/tools/parity` | Compares a machine's Clan and OnixOS derivations |
| `flake-outputs/_onixos-checks.nix` | Checks `onixos-services` (Nickel tests) and `onixos-<machine>` (toplevel) |

Only machines listed in `onixos/nix/machines.nix` are assembled; today that is aspen2.

## Evaluate and compare

`onix-modules` tracks OnixOS `main`, which carries the two fixes the pilot needs (`713d5d15`, `2d23df26`). Evaluate the OnixOS build directly:

```console
nix eval --raw .#onixos.nixosConfigurations.aspen2.config.system.build.toplevel.drvPath
```

Compare the two builds of aspen2. On this workstation keep auto-GC away from the fresh derivations:

```console
NIX_CONFIG=$'min-free = 0\nmax-free = 0' \
  onixos/tools/parity aspen2 "git+file://$PWD?rev=$(git rev-parse HEAD)"
```

The tool instantiates `clan.nixosConfigurations.aspen2` and `onixos.nixosConfigurations.aspen2`, roots both derivations, and prints `nix-diff` between them. Set `PARITY_GC_ROOT=<path>` to keep the roots for later inspection, and delete the `<path>-clan` and `<path>-onixos` links afterwards.

Run the module tests:

```console
nix build .#checks.x86_64-linux.onixos-services
```

The declared formatter finds its root through `flake.nix`, not `.git/config`.
This supports Git worktrees, where `.git` is a file; the same deadnix, Statix and
treefmt commit hooks run without a worktree-specific bypass.

## Parity

Every difference between the two aspen2 derivations is one of the following; `parity-evidence.json` in the Cairn change lists the derivations.

| Difference | Where | Why |
|---|---|---|
| Secret paths `/run/secrets/vars/per-machine/aspen2/<g>/<f>` and `/run/secrets/vars/shared/<g>/<f>` become `/run/secrets/<g>/<f>` | units, `sshd_config`, `ssh_config`, `nix.conf`, Grafana `config.ini`, borg wrapper, sops manifests, `users-groups.json` | OnixOS names sops secrets `<artifact>/<file>`. The sops manifests hold the same 18 secrets with the same ciphertext hashes, owners, modes and restart units. |
| `ExecStart`/`ExecStartPre` run a unit script, and the unit `PATH` gains the packages | arxiv-corpus, laya, mesh-llm and its watchdog, niks3 queue metrics and maintenance guard, tailscale host sync, tailscalesd | Nickel cannot write a store path into a string. Each script runs the same command; mesh-llm reads its invites from `$CREDENTIALS_DIRECTORY` instead of `%d` and sets `LD_LIBRARY_PATH` from `MESH_LLM_GCC_LIB`. |
| Files move from the store to `/etc` | mesh-llm `config.toml` and `research.json`, blackbox exporter config, build farm address wait script, SSH host certificate | Same reason. The contents match; the blackbox config is the same JSON pretty-printed with its build-time check off; mesh-llm's plugin and the wait script find their programs through `PATH`. mesh-llm and the blackbox exporter get restart triggers for their moved configs. |
| `onix/hardening-policy.json` and `onix/userland-profile.json` in `/etc` | `etc` | Added by every OnixOS assembly. |
| `borgbackup-create`, `borgbackup-list`, `borgbackup-restore`, `state-commands`, and the borg job's no-op pre/post hooks are gone | `system-path`, `unit-borgbackup-job-aspen1.service` | Clan backup-provider plumbing for `clan backups`; use `borg-job-aspen1` and `systemctl start borgbackup-job-aspen1`. |
| Order only | `environment.systemPackages` (framework-tool, opentofu, herdr, tailscale, mesh-llm), `nix.conf` `trusted-public-keys` (onix-niks3 key), kernel parameters (a duplicate `amd_pstate=active`) | Module order differs; the sets and values are equal. |

Everything else that differs only depends on these derivations.

The Clan build is unchanged: `nixosConfigurations.aspen2` at the pilot commit and at its base `18864766` differ only in `nixos-version`'s `configurationRevision`, the commit each build records. The pilot adds the `onix-modules` and `nixos-artifacts` inputs and changes no other locked input.

## Secrets

Each `onixos/secrets/machines/<machine>/<generator>/<file>` and `onixos/secrets/shared/<generator>/<file>` is a byte-identical copy of `vars/per-machine/<machine>/<generator>/<file>/{secret,value}` or `vars/shared/<generator>/<file>/{secret,value}`. For aspen2 that is 24 files:

- 18 secrets, copies of `secret` files: sops binary files whose data and MAC are AES-256-GCM ciphertext, encrypted with age to aspen2's key (`sops/machines/aspen2/key.json`) and to Clan's admins, user brittonr and machine aspen1. The shared ones are also encrypted to the other machines that use them. sops-nix decrypts them on aspen2 with the existing `/var/lib/sops-nix/key.txt`.
- 6 public files, copies of `value` files: the SSH public keys of `openssh`, `openssh-ca`, `nix-builder-ssh` and `borgbackup`, the SSH host certificate, and the Nix signing public key. OnixOS reads public artifact files during evaluation, so they stay plaintext, as Clan's `value` files do.

Evaluation fails when a file deployed as a sops secret is not a sops file encrypted to the machine's age key (`onixos/nix/encrypted-secrets.nix`). OnixOS itself only checks that a secret file exists, and sops-nix parses a binary-format file only as JSON, so a plaintext or wrongly encrypted copy would otherwise build, deploy, and fail at activation. The check reads only the sops envelope. It runs after evaluation has copied the flake source, file included, into the local store, so never commit a decrypted file. `onix artifacts status` does not see these modules' artifact declarations and cannot report on them.

Copy a file again after Clan regenerates it, always from the `secret` (or, for public files, `value`) file:

```console
install -D -m 0644 vars/per-machine/aspen2/<generator>/<file>/secret onixos/secrets/machines/aspen2/<generator>/<file>
```

Clan's `deploy = false` files are not copied, because OnixOS deploys every declared secret: the SSH CA key, the plaintext user password and the build farm CA key stay in `vars/`.

## Before the cutover

1. Run the parity tool and compare its output with the table above. After relocking `onix-modules` to a newer OnixOS, expect differences that the new OnixOS revision explains.
2. Review `parity-evidence.json`, this runbook and the gaps below.
3. Print the deploy plan from the OnixOS CLI shell (`nix develop .#cli` in the OnixOS checkout, which provides `onix` and the pinned `nickel`; pass `--lib <checkout>/lib` to a CLI built elsewhere). It contacts nothing:

   ```console
   onix deploy --dry-run aspen2 --inventory onixos/inventory.ncl
   ```

   It builds `.#nixosConfigurations.aspen2.config.system.build.toplevel` locally, copies it to `root@100.82.25.30` and activates it: `--action test` without safe mode, a switch in safe mode with a 300 s confirmation timeout. The local build needs aspen2's whole closure in the local store. `--build-on-target` does not fit this flake: it runs `nix build .#…` in root's working directory on aspen2, which holds no copy of it.
4. Record aspen2's SSH host key fingerprint from a client: `ssh-keyscan -t ed25519 100.82.25.30 | ssh-keygen -lf -`.

## Cutover

aspen2 was cut over on 2026-10-30 from `1cc80590`: it boots generation 15 (`ahgh4346…`), and generation 14 (`mz5i8w7c…`, Clan's build) is the rollback. `parity-evidence.json` (`cutover.deploy`) records the run.

`onix deploy` builds `nixosConfigurations.<machine>`. `cutOverMachines` in `flake-outputs/onixos.nix` lists the machines whose entry is their OnixOS build, and aspen2 is on it; `clan.nixosConfigurations.aspen2` keeps Clan's build for parity and rollback. The checks that read aspen2's configuration (`mesh-llm-sidecars`, `builder-no-self`, `niks3-*`, `radicle-*-policy`, `nixos-aspen2`) see the OnixOS build; the mesh-llm check reads the launch command, plugin configuration and invites from either build.

`clan machines update aspen2` would build the same entry, but deploy aspen2 with `onix`. The packaged `onix` puts stock Nix 2.31.3 first on `PATH`, and that Nix lacks `builtins.wasm`, which this flake needs; run the CLI with a Nix that has it, for example through a copy of the `onix` wrapper without that `PATH` entry.

```console
onix deploy aspen2 --inventory onixos/inventory.ncl --action test
onix deploy aspen2 --inventory onixos/inventory.ncl --force-activate --no-safe-mode
```

`--action test` activates the system and also sets the system profile (`nix-env --set`), but leaves the GRUB default alone, so a reboot returns to the previous generation. Every unit that names a secret restarts, including sshd and nix-daemon; the host key and certificate are the same bytes. A service that binds the Tailscale address can fail once while tailscaled restarts, as arxiv-corpus did, and its restart policy brings it back. After the test the running system and the profile already match, so a safe-mode `onix deploy` reports "already deployed" without installing the bootloader; `--force-activate --no-safe-mode` persists it and restarts nothing, because the running configuration does not change. Check after each step:

- `ls /run/secrets` shows the artifact directories, and `systemctl --failed` is empty;
- the fingerprint from step 4 of [Before the cutover](#before-the-cutover) is unchanged;
- `tailscale status`, `systemctl list-timers 'borgbackup-job-*' tailscale-host-sync.timer`, `curl -s 127.0.0.1:9090/-/ready`, `systemctl status nix-grpc-daemon mesh-llm-mesh-llm-private-inference`.

## Rollback

Safe mode reverts a switch that the deploy cannot confirm. After `--action test`, rebooting undoes it. Otherwise, after a test or a switch, return to the previous generation (14 is Clan's build) on aspen2:

```console
nix-env -p /nix/var/nix/profiles/system --rollback
/nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

Then remove aspen2 from `cutOverMachines` and deploy it through Clan again. Clan's secret paths come back with Clan's sops manifest.

## Mantle build

aspen2's typed services also build with Mantle, OnixOS's default backend, without running a Nix command. The result is not deployable in effect, so aspen2 stays on its Nix-backend generation. For a NixOS host, a Mantle deploy copies the artifact to `/tmp/onix-mantle-artifacts/aspen2/<hash>` and runs its entrypoints. Activate, status and persist only run `test -f system/payload-manifest.json`, and rollback is `true`. The system would not change, but `/run/onix-deploy-status.json` would then describe the Mantle artifact instead of the running generation.

The artifact holds manifests of the 24 lowered units of aspen2's typed services: units, providers, packages, files, artifacts and their wiring. Package references are not materialized. Kernel, boot, disko, hardware, Home Manager, the `.nix` sidecars and the Clan machine modules in `onixos/nix/machines.nix` have no Mantle path.

It needs an OnixOS checkout at `main` `0221b388` or later for `--lib` and the CLI. From fix `9addcea4` on, Mantle passes services the same placement facts, instance record and last-segment package handles as the Nix shim. The `onix-modules` lock (`2d23df26`) does not matter here: the Mantle build reads the library through `--lib`. Use the flake's pinned Mantle (`nix build <onixos>#mantle`, which brings bubblewrap and a static BusyBox) and two copies of that BusyBox: `busybox` alone in its directory, and `sh`. Run the unwrapped `onix-cli` package: the packaged `onix` wrapper puts Nix first on `PATH`.

```console
export PATH=<mantle>/bin:$PATH
export ONIX_MANTLE_BUILD_BUSYBOX=/path/busybox/busybox ONIX_MANTLE_BUILD_SHELL=/path/sh/sh
export ONIX_MANTLE_BUILD_STORE_DIR=/path/mantle-store
onix build --backend mantle --json --inventory onixos/inventory.ncl --lib <onixos>/lib \
  --services <onixos>/modules --services onixos/services aspen2 > build.json
onix deploy --dry-run --backend mantle --mantle-build-report build.json \
  --inventory onixos/inventory.ncl --lib <onixos>/lib aspen2
```

Never drop `--dry-run` for aspen2. `parity-evidence.json` (`mantle`) records a run with Nix programs replaced by logging stubs: zero calls, and the dry run accepted the proof.

## Mantle-built systemd-host candidate

`onixos/host/inventory.ncl` is a separate, experimental candidate for replacing
NixOS itself. It selects `class = 'onixos` and `onixos.runtime = 'systemd_host`,
not the NixOS service-manifest build above. `onixos/host/packages.nix` is the
offline Nix producer; `aspen2-packages.json` pins the signed binary-cache roots
that Mantle consumes. The candidate has not been installed on physical aspen2.
Its physical cutover still needs separate operator approval and must keep the
NixOS generations bootable.

The host inventory retargets the font instance by machine name, as it does users,
SSH and Tailscale: these instances otherwise select the `nixos` tag, which the
candidate does not carry. Berkeley Mono's encrypted artifact is installed by
`berkeley-mono-font-install.service`. Fontconfig's commands and configuration are
different package outputs: `fontconfig` supplies the commands and
`fontconfig-data=fontconfig.out` supplies `fonts.conf` and the default rules. A
rule in `/etc/fonts/conf.d` includes those defaults and adds
`/var/lib/fonts/berkeley-mono`. Extraction names its coreutils, tar and gzip
binaries explicitly. The Mesh-LLM launcher and watchdog likewise receive their
own package PATHs rather than depending on NixOS's service defaults.

The candidate also places `docker/host` directly on aspen2. Its host output in
`onixos/services/docker.ncl` supplies the daemon, API socket, both weekly pruning
timers, container sysctls and the existing Docker client tools. The daemon keeps
overlay2, journald logging, live-restore and the configured address pools. Its
pre-start commands install `/sbin/apparmor_parser` before daemon initialization:
containerd's [host-support check](https://github.com/containerd/containerd/blob/main/pkg/apparmor/apparmor_linux.go)
requires that absolute path and caches a negative result. A parser on `PATH` and
Docker's reported `docker-default` name alone do not prove kernel confinement;
the replica checks the actual container PID's AppArmor context. Already-running
unconfined containers are not retroactively confined by a daemon live-restore;
they must be recreated or restarted by an OS reboot.

The 2026-11-04 replica recovery built generation
`ibsayjv84zc4k6329cp93azcxi81sb3q-onixos-system-aspen2` on leviathan. Its direct
boot accepted the throwaway harness SSH key, preserved brittonr `1555:998`, sshd
`990:987` and the coredump group `986`, and activated the font unit. A valid open
DejaVu test font, encrypted under the fixture age key, was extracted byte-for-byte
and discovered by `fc-list` through its default configuration. No licensed font
or production secret was decrypted for this check.

Preserve the earlier failures separately: the first recovered run omitted its
root key override, although that guest reached `sshd`. The new generation's
initial GRUB attempt failed before Linux, with `fsck.fat` reporting only 8,188
clusters in the 256 MiB FAT32 ESP. The formatter had sized clusters for the
64 GiB backing disk. The harness now pins 512-byte sectors and one sector per
cluster for that ESP.

A separate VM-only replay repaired the ESP without rebuilding the generation,
retaining the failed ESP and firmware logs. `fsck.fat` accepted the replacement
with 516,190 clusters; all ESP file bytes survived a round-trip comparison. Two
consecutive firmware → GRUB → Linux boots passed, with boot IDs
`efb52b5a-9aac-4a4e-979a-4b76d7baee98` and
`218bc795-71a8-4eb7-861e-71a8f226c17f`. Both repeated the font byte/discovery checks,
authenticated the host certificate against the throwaway CA, executed Mesh-LLM
using its unit PATH, and ran the watchdog's inactive-service branch with
`Result=success` and `ExecMainStatus=0`. The only failed unit at each settled boot
was `tailscaled-autoconnect.service`, using the deliberately invalid test key.
The build report stayed byte-identical (SHA-256
`b5009acbeaf1573afe78d2cc1210d569fd848f627844fc4f39a6a3119fc6f666`), the logging Nix
stubs recorded zero calls across build and replay, and the owned replay QEMU was
stopped. The 23 service-module Nickel tests passed separately. This is neither a
fresh all-service lifecycle run nor an authenticated mesh proof.

The new fontconfig data pin names the existing cache-signed dependency of the
pinned command output. A supplemental offline nixpkgs evaluation timed out while
unpacking its Git cache; this record does not claim a freshly regenerated full
package index or a full flake gate.

The 2026-11-05 Docker candidate built generation
`3sss16n8qcip043yf2hvli43rpd9rz7m-onixos-system-aspen2` with 81 package roots.
Mantle reported one built generation, zero cached or failed generation builds,
strict hermeticity and no audit events; this does not mean every package closure
was freshly built. The existing Nickel contract files and consumer inventory
checks passed separately.

Its real `onix deploy --action switch` selected `system-3-link` and exited 0.
Switching a socket-activated daemon re-armed `docker.socket`, not the daemon
itself. Preserve both failed verifier attempts: the first used an unsupported
`deploy --services` argument; the second incorrectly expected socket re-arming
to trigger its injected daemon failure. Neither verifier was promoted.

The final VM check booted that generation through firmware and GRUB. For the
durability regression it removed only the owned current initrd and synced the
ESP as fixture setup, then ran the actual generated installer (exit 0). A
runtime-only Docker pre-start failure was explicitly triggered (exit 1), followed
by abrupt guest stop. All six kernel/initrd references across three retained
entries matched the built bytes. Two further firmware/GRUB boots passed socket
activation and access controls, a real BuildKit image build and Compose run,
bridge HTTP, journald logs, kernel `docker-default (enforce)`, missing-profile
refusal, reload/live-restore PID preservation and volume persistence. Both pruning
services removed unused containers, images, networks and anonymous volumes while
preserving the active workload. Owned containers and QEMU were cleaned up; the
read-only backing disk stayed byte-identical and recording Nix PATH stubs stayed
at zero.

Companion OnixOS commit `a8b53701` retains the source-free receipt and
prior-attempt bindings under
`.cairn/changes/onixos-systemd-host/evidence/20261105-docker-grub-vm/`, with a
two-member checksum manifest. Raw scripts, streams and disks remain outside the
repository. The saved read-only FAT diagnostic still exited 1 with dirty-bit,
4,697-unused-cluster and free-space-summary warnings; this is a boot-reference
durability proof, not a clean-filesystem result or a full retained-service
lifecycle pass.

For publication, the pilot's `onix-modules` input selects
`git+ssh://git@github.com/onixcomputer/OnixOS.git?ref=refs/heads/onixos-systemd-host`
instead of the operator's local worktree. The paired OnixOS revision is
`7743a771` (relocked from `a8b53701` on 2026-11-08); fetching it requires GitHub
SSH access. This remains a feature-branch dependency, not a main-branch release
or a completed landing gate. The relock leaves aspen2's NixOS build alone:
`onixos.nixosConfigurations.aspen2`'s toplevel at the `f8ff452c` pin differs
from the `a8b53701` one only through `nixos-version`'s `configurationRevision`
(`nix-diff`, impure evaluation), and `7743a771` adds only change documentation.

The declared Statix/nixfmt and Prettier stages subsequently normalized the
producer's assignment syntax and the index's JSON layout for commit. The VM
receipt keeps the executed pre-format byte pins; no VM rerun of those normalized
files is claimed. Sorted compact JSON for the entire index remained identical,
SHA-256 `c611b2750005fed21402375d633a0debbd21a7a8ac1f3dad591c3f2ad777afb0`.
The installer, Docker module and host instances remain byte-matched to the VM
execution pins.

All applicable pinned formatting and lint commands passed directly. Restoring
the aggregate treefmt wrapper reached its 600-second bound. A separate
240-second Nix producer re-evaluation timed out while restoring/building
import-from-derivation toolchain dependencies; it did not establish a regenerated
index or producer package-map equivalence result. Neither tooling timeout is
promoted to a pass or changes the earlier frozen VM observations.

Zram now uses the same pinned `zram-generator` 1.2.1 package and setup template
as aspen2's NixOS configuration. `onixos/services/zram.ncl` installs the generator
and its configuration: lz4, 87% of RAM, swap priority 100. As upstream NixOS does,
the setup unit has `X-RestartIfChanged=false`: switching generations must not
reset live swap. Changed zram policy requires reboot or a safe manual lifecycle.
The existing index gained its independently resolved pinned package path;
this is not a fresh complete producer evaluation.

The 2026-11-05 zram lane built A `niysnj5f…` and B `93pnh4hy…`, each with 82
package roots. The retained B native report is strict, one built, zero cached or
failed, and no audit events. The outer build SSH deadline lost B's original CLI
exit status; its later built report and runtime proof do not invent that exit.

The final detached verifier exited 0. It booted A, verified real swap and lz4
compressed-page counters, stopped/started the public `dev-zram0.swap` unit and
checked every byte of a 64 MiB anonymous-memory probe after swapoff. An unrelated
test switch to B preserved the setup invocation, swap UUID and probe data while
leaving the system profile on A. B was then persisted and booted through GRUB;
rollback returned to A and its subsequent GRUB boot passed the same swap policy.
The three boot IDs differ, both backing images remained byte-identical, recording
Nix PATH stubs stayed at zero and owned QEMU stopped.

The passing verifier is a copy-on-write continuation of the retained A fixture,
not a fresh single-attempt baseline-to-upgrade proof. Earlier attempts remain
failed: missing fixture tailnet bind address (remote activation exit 4), a
canceled explicit reset sequence, and a two-minute probe deadline that expired
before the slow configuration handoff. The absent-zram baseline and initial
activation were observed in those earlier attempts, not retroactively promoted.
The owned guest used a loopback stand-in for service bind addresses; pageout
probes temporarily disabled zswap and restored it to distinguish real zram
compression from zswap caching. Only the deliberately invalid tailnet-key unit
failed at each settled final boot. The companion OnixOS Cairn change retains
the source-free receipt and checksum under
`.cairn/changes/onixos-systemd-host/evidence/20261105-zram-vm/`; raw reports,
scripts and disks remain outside the repositories.

Thunderbolt now has a typed host module, placed directly on aspen2. The NixOS
tag and `onixos/services/thunderbolt-link.ncl` consume the same
`inventory/tags/thunderbolt-link.json` policy and
`inventory/tags/thunderbolt-link-guard.sh` body. They retain `br-tbt`,
`10.10.10.2/28`, MTU 65520, driver-matched members, configured-peer source
filtering, IPv6/transit denial, tunnel-event triggers and the periodic guard.
The link is not trusted: an early nftables table prevents a general port opening
from widening peer access. Source-address filtering is not peer authentication.

The shared guard also fixes a real hardening defect: dotted sysctl names were
used literally beneath `/proc/sys`, so the old existence check skipped them.
It now translates the dots to directory separators. Both rendered guards
changed real guest redirect/source-route sysctls from 1 to 0 and pinged the
configured virtual peers successfully.

The 2026-11-06 verifier built generation `bsscgkwb…` from 82 package roots:
CLI and owner exits 0, native strict report one built/zero cached/failed, no
audit events. The real CLI switched the disposable guest and its next
firmware/GRUB boot selected that generation. Virtual-link tests passed peer
HTTP access, non-peer denial with an open-port and table-removal positive
control, IPv6 input drops, detached-member denial, bidirectional transit drops,
address/MTU/qdisc repair, unreachable-peer failure, cooldown suppression,
expired-marker retry and recovery without another bounce. Missing bridge,
no carrier and no configured attachment also followed their public skip paths.
The immutable backing hash, zero recording Nix PATH-stub calls and owned QEMU
cleanup passed; only the deliberately invalid tailnet-key unit remained failed.

This tests kernel-backed bridge/packets/sysctls and the generated guard, not
physical USB4. The fixture changes only the member selector to veth and supplies
attachment labels through a guard-private sysfs bind. Networkd was temporarily
frozen for detached-member and address/MTU fault injection, then thawed; the
latter repair used the actual guard in a transient oneshot. IPv6 used explicit
neighbors and `nodad` addresses to avoid conflating discovery with input drops.
Four earlier fixture failures remain separate non-passes. The companion OnixOS
change retains their bindings and the passing source-free receipt/checksum under
`.cairn/changes/onixos-systemd-host/evidence/20261106-thunderbolt-vm/`.
Raw scripts, reports and disks remain outside the repositories. The final Nix
tag changed only its unknown-host diagnostic after the native snapshot;
re-evaluation preserved its generated guard and network-policy bytes.

The AMD exporter now has native host output and a five-second timer. Its collector
body is shared with the NixOS tag. An isolated data-path smoke checked edge and
junction temperatures, both supported power fields, and removal of stale metrics
after missing fields, malformed JSON or collector failure. The native unit also
checks for PCI vendor `0x1002`: a QEMU graphics card alone must not start ROCm.
An actual systemd fixture skipped absent/non-AMD cards without a failed unit and
executed an AMD-vendor positive control as an unprivileged user. These fixtures
do not exercise an AMD device or establish real telemetry.

The shared-body data-path run is retained in the companion OnixOS change as
`evidence/20261106-amd-collector-component/receipt.json`, with a relative checksum
manifest. It binds the formatted collector and controlled producer fixtures,
not the separate vendor-condition smoke or a complete host lifecycle.

The native package producer filters both system and Home Manager packages while
leaving the ordinary NixOS configuration unchanged. Home Manager's native flag
also disables the wrapped Helix Nix formatter/server references, rather than
removing `nil` from the package list while retaining it through generated editor
configuration. Other language settings remain. An explicit-module `config`
section fixes evaluation of the filter, and a regression now forces the native
Prometheus configuration with the fleet's 15-second intervals: caller values
override its lower-priority defaults while omitted fields keep their defaults.

The offline producer now realizes the 116-package index. Its Home Manager
wrapper makes the copied store payload's root, `bin` directory and activation
entrypoint writable before rewriting them; copying the original read-only modes
previously made the symlink update fail. The realized system profile was also
checked to exclude Xorg, LightDM, PipeWire/WirePlumber and `nixos-build-vms`,
alongside the checked Nix/heavy-tool commands. A working shell and executable Git
and NetworkManager commands remain. Home Manager activation itself
still requires the owned VM; never run it against the builder's home.

Full CLI lowering also caught a missing separator between the two GPU tmpfiles
entries and self-recursive PAM helper bindings. Both are corrected. The real
`--dry-run` now evaluates all selected host implementations and plans 116 roots
with zero recording Nix PATH-stub calls. Metadata-only tests had not forced those
outputs; this preflight is not an artifact build or runtime pass.

The complete generation subsequently exposed two additional contract defects:
the PAM package tag must be `linux_pam`, and Borg's generated command is not a
store program at `/etc/borgbackup/...`. The caller now uses the runtime tag and
the wrapper's `source_file` interface, which binds the generated script to its
own generation. Native `build-r2` remains a failed pre-artifact attempt; neither
that failure nor the earlier preflight is a completed host lifecycle.

A disjoint `lowering-preflight-r3` now passes both real CLI lowering and complete
generation JSON serialization with the corrected sources, input hashes unchanged
and zero recording Nix PATH-stub calls. This forces the nested runtime contracts
that the original dry-run did not evaluate; it still does not build an artifact
or establish live service behavior.

The next native build, `build-r3`, failed in the initrd: aspen2's NixOS
`amd-gpu` tag puts `amdgpu` in the initrd for early KMS, and the pinned driver
declares 725 firmware files, 38 of which `linux-firmware-20261019` does not
ship. The initrd had refused any absent declaration. It now packs the 687
shipped files and logs the rest, as NixOS's module closure does; absent
firmware declared by the configured rescue NIC driver still fails the build
(`r8169` declares 29, all shipped). Real Mantle builds of both branches passed
their expectations, and `build-r4` then built generation `drwzyhvj…` from 116
signed roots: strict report, one built, none cached or failed, no audit events
and zero recording Nix PATH-stub calls. A build is not yet a runtime result.

Its first real activation (`consume-a-r1`, a CLI `test` on a fresh baseline
replica) failed with switch exit 4, so the boot profile stayed unchanged. Home
Manager activation stopped on `genProfilePath: unbound variable`: the
Nix-command-free producer rewrite removes Home Manager's `setupVars`, and the
host wrapper had supplied only some of its globals. `wpa_supplicant` could not
own `fi.w1.wpa_supplicant1`: the bus had loaded its policies at boot, before
activation created the `wpa_supplicant` group, and nothing reloaded it; a
manual bus reload fixed it in the diagnostic. New sysctls stayed unapplied
(`vm.max_map_count` 65530 against the configured 1048576) because no switch
trigger restarted `systemd-sysctl`. Physical aspen2 has NixOS's trigger
drop-ins for sysctl, modules-load, udevd and its bus; OnixOS now renders the
equivalent drop-ins, and the wrapper defines every `setupVars` global. Three
ported units also had `X-StopIfChanged=false` in `[Unit]`, where the switcher
ignores it; aspen2 has it in `[Service]`, as these units now do.

The diagnostic also showed a fixture defect. Once the fixture Headscale
authenticated the replica (as `100.64.0.1`), Tailscale's anti-spoofing rule
dropped every loopback packet from the `100.82.25.30` stand-in address (4,782
matched), so arXiv, Laya and the mesh joiner timed out. On aspen2 that address
is Tailscale's own and exempt. A fresh fixture control server (`headscale-r3`)
occupies `.29` of `100.82.25.28/30` with a client-less placeholder and deletes
it, so the replica's own registration receives `100.82.25.30`; the generation
no longer carries a loopback stand-in. The probes now accept what aspen2 itself
shows: envfs as source `envfs`, type `fuse`; Music Assistant's same-origin
redirect to setup on a fresh install; and Prometheus targets discovered at the
replica's own tailnet address.

Generation `s065sl19…` (`build-r5`) carried those fixes. Its rehearsal on the
fresh `headscale-r3` replica (`verification-r3`) refused the planned report,
then passed the CLI `test`, seven application probes, `switch`, a reboot to a new
boot ID and seven application probes after it. Four boot-time host probe cases
(identity, Home Manager environment, network and mesh) failed, from four
causes:

- `wpa_supplicant` failed at boot with status 226 (`/dev/rfkill: No such file or
  directory`). The stock `kmod-static-nodes` condition names `/lib/modules`, so
  no static device nodes existed. aspen2's NixOS conditions it on the booted
  generation's module tree; OnixOS's base module now does too.
- The bus could not activate hostnamed: its alias
  `dbus-org.freedesktop.hostname1.service` was linked absolutely to the
  package's alias, which systemd refused (`File exists`). Package aliases now
  keep their relative links, as on NixOS.
- Fish sessions had an empty `NIX_LD`, and login `PATH` lacked Home Manager's
  per-user profile. aspen2's `/etc/pam/environment` carries both; OnixOS now
  renders it, `/etc/profile` and the fish preinit that aspen2's fish sources
  (`/etc/fish/nixos-env-preinit.fish`) from the same session variables,
  including NixOS's profile-relative search paths (`XDG_DATA_DIRS`,
  `TERMINFO_DIRS`, `XDG_CONFIG_DIRS`, `INFOPATH`) over the per-user and system
  profiles, so `host-common` no longer sets a system-only `TERMINFO_DIRS`.
- The mesh joiner's handshake failed (`invalid peer certificate:
  UnknownIssuer`). The fixture seed runs client-only, and Mesh-LLM gives a client
  a new node identity at every start, so the invite captured at build time went
  stale when the switch restarted the seed. The production seeds are
  long-running serving nodes. As a declared fixture step, the probe now
  re-issues the invite from the running seed and restarts only the joiner, and
  the seed accepts the replica's tailnet address, which the production joiner
  binds. Rehearsed on the same replica, the joiner then connected within
  seconds. The joiner's refusal of the stale identity is the expected
  authentication behavior.

The first final run (`headscale-r4`, `candidate-r4`, generation `fml5imcd…`
from `build-r7`) refused the planned report and passed the CLI `test` and seven
activation probes. Its switch step then failed after 25 minutes with only
`Broken pipe (os error 32)`: the deploy writes the closure's 2,305 paths to an
ssh child whose input closed before it read them, and the CLI discarded that
child's status, so the cause is not recorded. The guest journal shows no
authenticated session in that window and the boot profile was unchanged; the
builder was heavily loaded by unrelated jobs, no OOM kill was logged, and a
later read-only dry run walked the same closure in 6 minutes 16 seconds.
`onix deploy` now reports such a child's exit status. Resumed on the same
replica, the switch, a firmware boot, all seven application probes and eight of
nine host probe cases passed. Apart from a probe defect of its own (`runuser -l`
starts its shell as `-printenv`, which multicall coreutils rejects), the Home
Manager case found two host defects:

- `/etc/shells` lacked fish, brittonr's login shell, which aspen2's NixOS lists
  through `programs.fish`. Host outputs now contribute `shells`, and planning
  refuses an unlisted login shell.
- The system profile linked `share/man/man1` from `clinfo` alone, hiding every
  other package's pages, so `man bash` failed. Package `share` trees are now
  merged at every depth, as NixOS's `buildEnv` does.

These fixes change the generation, so the final run restarts from fresh
fixtures.

The second final run (`headscale-r5`, `candidate-r5`, generation `cwbl8rv7…`
from `build-r8`) refused the planned report and passed the CLI `test`. Its
first activation probe ran while Prometheus still reported its replica's own
just-discovered node exporter as `unknown`, so the probe now waits up to 120
seconds for every target's first scrape; a resume on the unchanged guest (all
other inputs byte-identical) then passed activation probes, `switch`, a firmware
boot, seven application probes and all nine host probe cases. The B lifecycle
passed in full: Docker on A, B `test` (Homepage restarted, swap and container
preserved), B `switch` and firmware boot with all probes, rollback, and a
firmware boot back into A with all probes and Docker cleanup. Private initrd
recovery then failed twice on its harness (aspen2 lists `tty0` as its last
console, hiding the initrd's messages from the serial log; the builder's ssh
configuration multiplexes connections, so the "wrong key" client reused the
fixture client's authenticated connection). The third attempt passed the
public-image refusal, private recovery, wrong-client refusal, failed-fsck
recovery and a clean root fsck, then hung: stage 1 waited for its interactive
recovery shell after SIGTERM, which such shells ignore. Stage 1 now kills that
shell with SIGKILL. The initrd changes the generation, so the lifecycle runs
again from fresh fixtures.

The third final run passed end to end on one replica (`headscale-r6`,
`candidate-r6`). Generation A `jp3zrzp9…` (`build-r10`) and B `j0d1anrc…`
(`build-r11`) were each one strict Mantle build of 116 signed roots with no
audit events and zero recording Nix PATH-stub calls. A's planned report was
refused; the CLI `test`, seven activation probes, `switch` and a firmware boot
with seven application and nine host probe cases passed without a resume. The
B lifecycle then passed Docker on A, B `test`/`switch`/firmware boot, rollback
and a firmware boot back into A, with all probes after each boot. Private
initrd recovery passed on copy-on-write children of that replica: the public
image refused rescue; the private image accepted only the pinned rescue
identity before root, refused a wrong client key, survived a real fsck failure
with the root unmounted, and retried with the real root into stage 2, where
the rescue was gone. The source-free receipt is
`.cairn/changes/onixos-systemd-host/evidence/20261108-aspen2-lifecycle-vm/receipt.json`
in the OnixOS repository; it classifies the 23 earlier attempts above.

Producing an index does not publish its new configuration-profile closures to
the declared caches. The replica lane uses a separate loopback cache and local
test signer; that signer is not upstream provenance or production fleet trust.
The checked-in index keeps the original fleet/public cache declarations and the
realized package paths, and on 2026-11-08 those caches served its whole
2,309-path closure: 1,404 paths from cache.nixos.org and 905 fleet-built paths
from aspen1's Harmonia (`http://100.100.103.95:5000`, key `aspen1-1`). 33 of the
fleet-built paths (Home Manager configuration, service wrappers, the system
tools profile, the initrd's static dropbear and e2fsprogs) had reached only the
test cache, so they were copied into aspen1's store from the producer store.
Their narinfos as Harmonia serves them carry the NAR hashes the replica
consumed, and `nix store verify` downloaded and checked each against `aspen1-1`
alone. A scratch Mantle pull of the committed index, made as `onix build` makes
it (each root's complete closure from the first declared cache that signs it),
imported all 2,309 paths: 101 roots from cache.nixos.org and 15 from aspen1. It
built no generation.

Harmonia serves aspen1's own store, which aspen1's weekly `fast-nix-gc`
collects. The 15 fleet-built index roots are GC roots on aspen1 under
`~brittonr/.local/state/onixos-aspen2-host-cache`; delete that directory once
no build needs this index.

Retained-service parity is shown on the replica only. Real AMD telemetry,
physical Thunderbolt driver, tunnel-event and DMA recovery, physical Wi-Fi and
modem behavior remain unproved, and the local Headscale and mesh fixtures do not
establish production network or mesh authentication. The full OnixOS flake gate
at `7743a771` passed 298 of 300 checks; its two Cairn readiness checks fail, as
they did before this work, until the `onixos-systemd-host` change is archived or
its code markers are neutralized, which landing on main requires. VM results
never authorize physical installation.

## Gaps

- The NixOS inventory's Mantle path remains a service-manifest build, not host activation ([Mantle build](#mantle-build)). The separate [systemd-host candidate](#mantle-built-systemd-host-candidate) supplies a bootable generation whose retained services passed a complete replica lifecycle; physical-hardware parity and operator authorization still block replacing aspen2's operating system.
- `onix check onixos/inventory.ncl --services onixos/services` reports 24 C012 findings: raw `networking.firewall`, `users`, `systemd.timers` and `systemd.tmpfiles` leaves where OnixOS wants typed providers. The providers cannot express what Clan configures: interface-scoped firewall ports (`tailscale0` for arxiv-corpus, laya and the build farm), relative timers (`OnBootSec`/`OnUnitActiveSec`), recursive ownership (`Z`) rules, root's authorized keys, extra groups of an existing service user, or a password hash wired from a secret. Converting the expressible subset would still leave the check failing.
- OnixOS cannot keep generated but undeployed secrets, upload activation-time secrets, or order generators by their dependencies, and its prompts have no hidden or persist flags. Regenerating the `deploy = false`, activation and prompted secrets still needs Clan.
- `system.stateVersion` still comes from `vars/per-machine/<machine>/state-version`.
- Roles on other machines are not ported: the niks3 server, the build farm scheduler, balancer and clients, the borg server, the mesh-llm seed and forwarder, laya's Vulkan instance and the other Home Manager instances. Porting another machine starts with adding it to `onixos/nix/machines.nix`.
