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
`a8b53701`; fetching it requires GitHub SSH access. This remains a feature-branch
dependency, not a main-branch release or a completed landing gate.

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

This is not complete retained-service parity. In particular, the Thunderbolt
bridge and guard, zram swap, and the AMD GPU exporter timer still need host output
and appropriate runtime or hardware verification. Dummy tailnet and mesh credentials
do not establish authenticated network operation. VM results do not authorize
physical installation or prove GPU/USB4 behavior, and the OnixOS branch still
needs its remaining integration coverage and landing gates.

## Gaps

- The NixOS inventory's Mantle path remains a service-manifest build, not host activation ([Mantle build](#mantle-build)). The separate [systemd-host candidate](#mantle-built-systemd-host-candidate) supplies a bootable generation, but retained-service and physical-hardware parity still block replacement of aspen2's operating system.
- `onix check onixos/inventory.ncl --services onixos/services` reports 24 C012 findings: raw `networking.firewall`, `users`, `systemd.timers` and `systemd.tmpfiles` leaves where OnixOS wants typed providers. The providers cannot express what Clan configures: interface-scoped firewall ports (`tailscale0` for arxiv-corpus, laya and the build farm), relative timers (`OnBootSec`/`OnUnitActiveSec`), recursive ownership (`Z`) rules, root's authorized keys, extra groups of an existing service user, or a password hash wired from a secret. Converting the expressible subset would still leave the check failing.
- OnixOS cannot keep generated but undeployed secrets, upload activation-time secrets, or order generators by their dependencies, and its prompts have no hidden or persist flags. Regenerating the `deploy = false`, activation and prompted secrets still needs Clan.
- `system.stateVersion` still comes from `vars/per-machine/<machine>/state-version`.
- Roles on other machines are not ported: the niks3 server, the build farm scheduler, balancer and clients, the borg server, the mesh-llm seed and forwarder, laya's Vulkan instance and the other Home Manager instances. Porting another machine starts with adding it to `onixos/nix/machines.nix`.
