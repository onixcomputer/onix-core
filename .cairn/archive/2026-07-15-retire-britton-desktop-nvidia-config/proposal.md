## Why

`britton-desktop` no longer contains an NVIDIA GPU. Live PCI inventory shows only the AMD Granite Ridge display controller and two Tenstorrent Blackhole accelerators, but the machine still carries the `nvidia` tag and an NVIDIA-only Krea SGLang service assignment. The stale configuration can install unusable drivers, expose nonexistent `/dev/nvidia*` devices, and mislead runtime placement decisions.

Tenstorrent is now the host's accelerator platform. Its generated operator guide should reference the official TT-Metalium debugging tools and describe which diagnostics are available from the packaged runtime versus a matching source checkout.

## What Changes

- Remove the `nvidia` tag from `britton-desktop` and regenerate its live `nixos-facter` report without applying the Strix-Halo-specific `amd-gpu` compute tag to its Granite Ridge display controller.
- Remove the NVIDIA-only Krea SGLang service assignment from `britton-desktop`.
- Add a regression check that requires the Tenstorrent tag and rejects the NVIDIA tag for this machine.
- Add the official TT-Metalium tools index and an Inspector/tt-triage/Watcher workflow to the generated Tenstorrent host guide.
- Record the current hardware boundary in agent guidance and remove stale NVIDIA-specific display comments.

## Impact

- **Files**: machine/service inventory, machine checks, Tenstorrent host documentation, desktop guidance, and this Cairn change package
- **Runtime**: NVIDIA driver configuration and the unusable NVIDIA Krea unit leave the next `britton-desktop` generation; VibeThinker and Supra remain on their isolated P150 cards
- **Validation**: positive/negative accelerator inventory check, formatting, pre-commit, full host build/switch, PCI inventory, unit absence, and both Metalium model health probes
