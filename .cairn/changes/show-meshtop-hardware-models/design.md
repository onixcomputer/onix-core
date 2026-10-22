# Hardware-name display design

## Source of names

Meshtop's collector obtains the CPU brand from its existing sysinfo CPU list once at startup, trims and bounds it, and adds an optional CPU-model field to each snapshot. The optional field preserves decoding of older agents without a CPU model. For AMD DRM cards, the collector resolves the corresponding PCI slot once at discovery and reads at most 4097 bytes from the host's `/run/udev/data/+pci:<slot>` entry. `ID_MODEL_FROM_DATABASE` supplies the label. If missing, invalid or oversized, the collector uses the sysfs PCI device ID (or explicitly reports an unknown model); it does not select one of several marketing SKUs from an ambiguous PCI database entry. The same model string accompanies the existing counters; no new sensor or command execution is added.

The compact UI uses the CPU and GPU model in existing section-heading rows when height permits. Shorter cards keep the CPU name and utilization on the same row, clipping the name before the percentage and meter rather than hiding it; they also clip long GPU names before the busy percentage and meter, retaining VRAM on its own row. The full UI gives each model a separate row before the existing utilization and per-core/VRAM data. Names in received snapshots are not authority or host identity; the roster and authorized Iroh endpoint IDs remain unchanged. GPU counters remain AMD-only.

## Adoption and rollback

The Meshtop repository owns the implementation and committed revision. onix-core's exact-revision sync script copies that clean revision and lockfile into its Nix package. Build the same generated system unit for Aspen3 and Bonsai, copy its closure over their already authenticated SSH routes, retain it with scoped remote GC roots and restart only their Meshtop services. Rebuild and link only the desktop Home Manager-generated user unit, upgrade the viewer package and restart only its Meshtop user agent. Preserve existing agent and viewer private keys and the three public roster IDs.

Do not claim a whole NixOS/Clan generation switch or reboot continuity. A later managed switch must retire scoped `system.control` links only after confirming its managed Meshtop unit and a live authenticated sample. A source rollback restores the prior pinned revision, matching generated units and viewer package while retaining the same keys and roster IDs. The displayed name reflects the host's CPU and PCI databases, which can be broader than a unique retail model.
