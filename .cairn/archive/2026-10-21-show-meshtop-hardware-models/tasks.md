# Show Meshtop hardware model names

## Phase 1: Bounded source and behavior

- [x] [serial] Report sanitized CPU brands and PCI-database AMD GPU models with honest fallbacks; show them in compact/full panels and decode older agent snapshots. r[onix.meshtop.hardware-model] r[onix.meshtop.hardware-view.legacy]
- [x] [serial] Exercise the GPU fixture, viewer rendering, full source suite and a real local paired hardware-model sample. r[onix.meshtop.hardware-model.named] r[onix.meshtop.hardware-model.fallback]

## Phase 2: Import and selected host activation

- [x] [serial] Import the clean committed Meshtop revision through onix-core's exact-pin sync script; build the Nix package and selected generated units. r[onix.meshtop.hardware-view]
- [x] [serial] Update only the Aspen3, Bonsai and desktop Meshtop units and desktop viewer, preserving keys, roster IDs and unrelated system generations. r[onix.meshtop.hardware-view.grid]

## Phase 3: Evidence and checks

- [x] [serial] Observe all three CPU/GPU model names and live counters in the paired JSON and terminal dashboard; document ambiguous names, rollback and deployment limits; run focused Nix, whitespace and Cairn checks. r[onix.meshtop.hardware-model] r[onix.meshtop.hardware-view]
