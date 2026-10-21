# Aspen2 NixOS installation

Date: 2026-09-06 UTC

## Result

NixOS replaced the native OnixOS installation. The installed system booted and accepted SSH with the host key from Clan vars.

Qwen and the mesh endpoint are not ready. Tailscale needs a new login, and Qwen failed GPU cache allocation.

## Authority and source

The user explicitly authorized NixOS replacement after the disk-erasure warning.

- Repository: `onix-core`
- Branch: `qwen38-flash-next-aspen2`
- Source commit: `9a3d9ad96aa4c2621dfbf15bb2b746550bcb974f`
- Install target: `root@192.168.1.130`
- SSH identity: `~/.ssh/framework`
- Verified disk serial: `S7KHNU0YA15603E`
- Installed system: `/nix/store/0bbdb63g18ab88c2nnvlayv7ab2c1i09-nixos-system-aspen2-26.11.20260819.afe3d8a`
- Booted kernel: `7.2.0`

No source configuration or lock file changed during installation.

## Data preservation

The persistent OnixOS state contains the Calibre database and configuration.
Its backup passed archive extraction and SQLite integrity checks. The database contains zero books.

- Workstation backup: `~/.local/state/onix/deployments/aspen2-20260906/persistent-state.tar`
- Aspen2 backup: `/root/onixos-backup/persistent-state.tar`
- Matching BLAKE3: `1fb129ca12e61d66f7fec68f619f7f32e47944dbcf40fad53829f536d4fe50d3`

The new configuration does not enable a Calibre service on Aspen2. The backup preserves its old state without adding that service.

## Installation evidence

Two read-only agent reviews covered the source configuration and installer mechanics.

- The complete system and disko script built successfully.
- `clan vars check aspen2` reported that all vars are present and valid.
- The disk identity matched `machines/aspen2/disko.nix` before erasure.
- The kexec installer booted with `iommu=pt`, as required by the known Aspen2 network path.
- Clan installed the new partition layout, system, secrets, and both GRUB bootloader targets.
- `/` mounts `/dev/nvme0n1p3` as ext4.
- `/boot` mounts `/dev/nvme0n1p2` as vfat.
- The EFI fallback loader exists at `/boot/EFI/BOOT/BOOTX64.EFI`.
- `/run/current-system` matches the installed system path after reboot.
- `sshd.service` is active.
- `/onixos/bin/onixos-status` is absent after reboot.

The stock `nixos-anywhere` wrapper selected Nix without `builtins.wasm` after the successful kexec step.
A local wrapper selected Onix Nix for the remaining `disko,install` phases. The kexec step did not repeat.

The installer helpers remain under the workstation deployment directory, outside the repository.

## Model artifacts

The four model files came from the existing Aspen1 model directory.
A direct rsync transfer resumed the partial workstation transfer. Aspen1 kept its model service active.

All four files matched the pinned Hugging Face LFS SHA-256 values from `inventory/services/services.ncl`.
SHA-256 is required by that existing artifact contract.

The model pull service completed successfully after the NixOS boot.
The Hugging Face environment file has mode `0400` and owner `root:root`.
No credential value appears in this receipt.

## Remaining blockers

### Tailscale login

The configured auth key failed with:

```text
backend error: invalid key: API key does not exist
```

The stored key is the same on this branch and local `main`.
Aspen2 remains in `NeedsLogin` without a Tailnet address. A browser login URL was supplied to the user.

The mesh configuration currently binds to `100.125.64.121`.
The address needs verification after login before mesh acceptance can continue.

### Qwen GPU allocation

The service passed its model checks but failed during context creation:

```text
allocating 408.00 MiB on device 0: cudaMalloc failed: out of memory
failed to initialize the context: failed to allocate buffer for kv cache
```

This message comes from the ROCm backend. It does not indicate an NVIDIA GPU.

The observed memory allocation differs from the tested Aspen1 setup:

| Host | VRAM bytes | GTT bytes | Linux memory, kB |
| --- | ---: | ---: | ---: |
| Aspen2 | 68719476736 | 67192324096 | 65621132 |
| Aspen1 | 536870912 | 133143986176 | 131161628 |

`machines/aspen2/configuration.nix` documents a small BIOS VRAM reservation of 0.5 GB.
Aspen1 uses 512 MiB and serves the same model successfully.
The installed `framework_tool` exposes no VRAM-setting command.
No firmware write, context reduction, or backend change was attempted.

Qwen failed twice, and its restart counter reached two. The operator stopped its restart loop and the unavailable mesh service.
They remain enabled in the source configuration. Another boot can attempt startup again.

The next hardware step is the documented 512 MiB BIOS reservation, then another boot and service validation.
This receipt does not claim that this untested change resolves every model problem.

## Evidence and non-claims

Detailed logs and the model checksum list remain in:

`~/.local/state/onix/deployments/aspen2-20260906/`

Relevant files include `install.log`, `model-hashes-final.log`, `preboot-checks.log`, `boot-success.log`, `qwen-loading.log`, and `final-host-state.log`.

This receipt proves NixOS installation and SSH access. It does not prove Qwen health, inference, vision, mesh routing, or Tailnet access.
