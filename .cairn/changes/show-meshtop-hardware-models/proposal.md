# Show Meshtop CPU and GPU hardware models

## Why

The paired three-host dashboard reports CPU usage with only `CPU` and labels AMD GPUs by DRM index (`AMD card0` or `AMD card1`). Those labels do not identify the hardware being measured.

## What Changes

- In the standalone Meshtop source, report the bounded CPU brand and resolve each AMD GPU's bounded PCI model name from its host's read-only udev device entry. If the GPU model is missing, display the PCI vendor/device ID when available, not an invented product name.
- Show the model names in compact and full TUI panels without hiding usage, temperature, memory, or per-core readings. Older agents without a CPU model remain readable with an explicit unavailable label.
- Sync a reviewed, committed Meshtop revision into onix-core, refresh the three selected agents and desktop viewer without rotating identities or switching unrelated NixOS generations, and record the source and activation boundaries.

## Impact

- **Owners:** The Meshtop repository owns sampling, wire compatibility and TUI rendering; onix-core owns the pinned import, selected services, deployment and operator instructions.
- **Boundaries:** Names come from host-reported CPU/PCI data and can be ambiguous about an exact marketing SKU. The AMD-only counter scope and paired read-only authorization do not change. CPU/GPU model names become visible to the already-authorized viewer; no private keys enter a Nix store path.
- **Verification:** Source unit and local authenticated smoke tests, exact Nix package and generated-unit builds, checked source revision, live paired samples from the three selected hosts, compact/full terminal rendering, and native Cairn validation.
