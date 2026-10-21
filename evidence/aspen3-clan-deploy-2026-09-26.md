# Aspen3 Clan deployment

Date: 2026-09-25 to 2026-09-26

## Causes

Evaluation of the aspen3 toplevel failed on `modules/arxiv-corpus/schema.ncl`, which Git did not track. The configuration imports 52 untracked files from other in-flight changes under `inventory/`, `machines/`, `modules/` and `pkgs/`; they were marked intent-to-add.

Evaluation then failed with `Grafana email-template manifest is malformed, duplicated, or version-mismatched`. The pinned nixpkgs ships Grafana 13.1.6, and the manifest named 13.1.4. All 18 vendored files pass `b3sum --check` against the Grafana 13.1.6 `public/emails` sources.

The first `clan machines update aspen3` evaluated on `root@britton-desktop`. Fetching `ssh://git@github.com/OnixResearch/bounded-exec.git` failed with `Permission denied (publickey)`. Clan resolves a build host without a user to root, and root on the desktop has no GitHub key.

That run also generated new desktop Underclass vars, because only the isolated Underclass worktree held them. The vars commit was amended to carry that worktree's ciphertexts. By SHA-256 comparison, the committed proxy key equals the key in the running desktop `underclass.service` environment.

## Corrections

- `inventory/core/machines.ncl` sets the aspen3 build host to `brittonr@britton-desktop`.
- The Grafana manifest (`json`, `ncl`, `blake3`) names 13.1.6.
- `modules/llm-agents` gains `ompUnderclassRemoteHost`, and aspen3 uses it for the desktop pool instead of a second local pool.

The laya and mesh-llm unit links in `/etc/systemd/system.control` moved to `/root/pre-clan-2026-09-25/system.control/`. The hand-installed tunnel unit, its `default.target.wants` link and `~/.omp/agent/extensions/underclass` moved to `~brittonr/.local/state/underclass-aspen3/pre-clan-backup/`. Compared with the Clan units, laya differed only in `Description`, and the mesh-llm configuration differed only in the research plugin store path.

## Checks

- `checks.x86_64-linux.grafana-email-templates` built `/nix/store/52gvggsjhbic0c57zp2jbpqcm2r1snlw-grafana-email-templates-check`.
- `clan vars check` reported all vars present and valid for aspen3 and britton-desktop.
- The aspen3 toplevel built on britton-desktop as brittonr.

## Deployment

The second run built as brittonr and copied 14 paths, then stalled at `test -e` on aspen3 until the 3600 s command limit. The aspen3 root session opened at 21:23:55 EDT never closed. Afterwards, the copied toplevel and an earlier pre-copied closure were absent from the aspen3 store. aspen3 runs `min-free = 100 GiB` with about 101 to 111 GiB free. The closure was copied again (571 paths in 141 minutes) and held by a temporary GC root, which was removed after activation.

The third run exited 0. Clan registered the generation, and GRUB reported `Installation finished. No error reported.` The first switch returned 4 because `celld-site-storage-provision.service` could not reach RustFS on `100.108.13.4:39000`. The retry also returned 4, and Clan accepted the switch after `/run/current-system` matched.

The previous system was `/nix/store/cksnpv3k312llj8k8j6y0ar54mf0462f-nixos-system-aspen3-26.11.20260913.02f5696`. `/run/current-system` and `system-91-link` now point to `/nix/store/73c859193pzbz0arphk4nlvahkqrhq50-nixos-system-aspen3-26.11.20260924.34ca302`. The closure grew from 4763 to 4813 paths (+2.03 GiB).

## Runtime result

- `laya-laya-aspen3.service` and `mesh-llm-mesh-llm-private-inference.service` are active from `/etc/systemd/system`. `/etc/systemd/system.control` is empty.
- mesh-llm restarted at 10:27:58 EDT with `/nix/store/gnxdmsdzp1q065v1fapr46pvqjkwdali-mesh-llm-mesh-llm-private-inference-config.toml`, loaded its model, and listens on `127.0.0.1:9337` and `127.0.0.1:3131`. Laya listens on `100.108.13.4:7999`.
- The OMP extension and tunnel unit link into `/nix/store/iv2cagrrg5r1578pn77pz2cxbj4spjzc-home-manager-files`. No `.hm-bak` files exist. Home Manager restarted `underclass-ssh-tunnel.service` at 10:28:03 EDT.
- Through the tunnel, `http://127.0.0.1:8080/` returns 200 and `/v1/models` without a key returns 401.
- The only failed unit is `celld-site-storage-provision.service`, which also failed before the switch.

## Limits

- The provider key command `ssh britton-desktop cat /run/secrets/vars/per-machine/britton-desktop/underclass/proxy-key` fails with `No such file or directory`. The desktop service still runs from its 2026-09-24 runtime install, whose `/run` secrets a later desktop activation removed. OMP on aspen3 cannot authenticate to the pool until britton-desktop is deployed through Clan.
- No reboot ran. The booted system keeps kernel 6.18.51 until the next boot into 6.18.53.
- After the switch, the tailnet path from britton-desktop to aspen3 was relayed through DERP Miami with 0.46 to 2.9 s pings. It was direct on 2026-09-25. The cause is not established.
- RustFS, celld and Kache on aspen3 stay down while `/mnt/usb4-nvme` is absent.
- aspen1, aspen2, pine and the Cloud Hypervisor VMs still name the bare `britton-desktop` build host.
- Cairn validation used the installed `/nix/store/j3ni3lj66ylskpcg78ip531s9lz4z4av-cairn-0.1.0` binary with the canonical policy path. Building the local checkout failed because `git.onix.computer` returned HTTP 530 for `bounded-exec`, and the policy path through the `/home/brittonr/git/cairn` symlink is rejected.
