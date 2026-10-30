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

`onix-modules` is pinned to OnixOS branch `onix-core-consumer`, which carries the two fixes the pilot needs (`713d5d15`, `2d23df26`), until they are on OnixOS `main` (see [Before the cutover](#before-the-cutover)). Evaluate the OnixOS build directly:

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
| Order only | `environment.systemPackages` (framework-tool, opentofu, herdr, tailscale, mesh-llm), `nix.conf` `trusted-public-keys` (onix-niks3 key), kernel parameters (a duplicate `amd_pstate=active`), mesh-llm `LoadCredential` lines | Module order differs; the sets and values are equal. |

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

1. Once the fixes (`713d5d15`, `2d23df26`) are on OnixOS `main`, drop `?ref=onix-core-consumer` from the `onix-modules` URL in `flake.nix` and relock: `nix flake update onix-modules`.
2. Run the parity tool and compare its output with the table above.
3. Review `parity-evidence.json`, this runbook and the gaps below.
4. Print the deploy plan from the OnixOS CLI shell (`nix develop .#cli` in the OnixOS checkout, which provides `onix` and the pinned `nickel`; pass `--lib <checkout>/lib` to a CLI built elsewhere). It contacts nothing:

   ```console
   onix deploy --dry-run aspen2 --inventory onixos/inventory.ncl
   ```

   It builds `.#nixosConfigurations.aspen2.config.system.build.toplevel`, copies it to `root@100.82.25.30`, and switches in safe mode with a 300 s confirmation timeout.
5. Record aspen2's SSH host key fingerprint from a client: `ssh-keyscan -t ed25519 100.82.25.30 | ssh-keygen -lf -`.

## Cutover

`onix deploy` builds `nixosConfigurations.<machine>`, so point aspen2's entry at the OnixOS build in `flake.nix`:

```nix
flake =
  let
    clanOutputs = import ./flake-outputs/clan.nix {
      inherit (inputs) self;
      inherit inputs;
    };
    onixosOutputs = import ./flake-outputs/onixos.nix {
      inherit (inputs) self;
      inherit inputs;
    };
  in
  clanOutputs
  // (import ./flake-outputs/effects.nix { inherit inputs; })
  // onixosOutputs
  // {
    nixosConfigurations = clanOutputs.nixosConfigurations // {
      inherit (onixosOutputs.onixos.nixosConfigurations) aspen2;
    };
  };
```

`clan.nixosConfigurations.aspen2` keeps Clan's build for parity and rollback. Then deploy with `onix`, not `clan machines update`:

```console
onix deploy aspen2 --inventory onixos/inventory.ncl --action test
onix deploy aspen2 --inventory onixos/inventory.ncl
```

`--action test` activates without changing the boot default. Every unit that names a secret restarts, including sshd and nix-daemon; the host key and certificate are the same bytes. Check afterwards:

- `ls /run/secrets` shows the artifact directories, and `systemctl --failed` is empty;
- the fingerprint from step 5 of [Before the cutover](#before-the-cutover) is unchanged;
- `tailscale status`, `systemctl list-timers 'borgbackup-job-*' tailscale-host-sync.timer`, `curl -s 127.0.0.1:9090/-/ready`, `systemctl status nix-grpc-daemon mesh-llm-mesh-llm-private-inference`.

## Rollback

Safe mode reverts a switch that the deploy cannot confirm. After `--action test`, rebooting or reactivating the boot default undoes it: `/nix/var/nix/profiles/system/bin/switch-to-configuration switch`. After a switch, on aspen2:

```console
nix-env -p /nix/var/nix/profiles/system --rollback
/nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

Then revert the `flake.nix` change and deploy aspen2 through Clan again. Clan's secret paths come back with Clan's sops manifest.

## Gaps

- `onix check onixos/inventory.ncl --services onixos/services` reports 24 C012 findings: raw `networking.firewall`, `users`, `systemd.timers` and `systemd.tmpfiles` leaves where OnixOS wants typed providers. The providers cannot express what Clan configures: interface-scoped firewall ports (`tailscale0` for arxiv-corpus, laya and the build farm), relative timers (`OnBootSec`/`OnUnitActiveSec`), recursive ownership (`Z`) rules, root's authorized keys, extra groups of an existing service user, or a password hash wired from a secret. Converting the expressible subset would still leave the check failing.
- OnixOS cannot keep generated but undeployed secrets, upload activation-time secrets, or order generators by their dependencies, and its prompts have no hidden or persist flags. Regenerating the `deploy = false`, activation and prompted secrets still needs Clan.
- `system.stateVersion` still comes from `vars/per-machine/<machine>/state-version`.
- Roles on other machines are not ported: the niks3 server, the build farm scheduler, balancer and clients, the borg server, the mesh-llm seed and forwarder, laya's Vulkan instance and the other Home Manager instances. Porting another machine starts with adding it to `onixos/nix/machines.nix`.
