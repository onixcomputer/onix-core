# Enroll SSH-reachable machines in Meshtop

## Phase 1: Inventory and selection

- [x] [serial] Enumerate the core and optional DGX machine inventories, probe each declared SSH target without accepting new host keys or prompting for passwords, and record reachable and excluded machines. r[onix.meshtop.reachable-fleet]

## Phase 2: Bonsai agent

- [x] [serial] Opt Bonsai into the existing authorized Meshtop service; build its exact generated NixOS unit and activate only that unit with a GC root, a unique private on-host identity, and no unrelated generation switch. r[onix.meshtop.reachable-fleet.selection]

## Phase 3: Expanded desktop roster

- [x] [serial] Pin Bonsai's observed public ID in the desktop Home Manager roster without changing the Aspen3/desktop IDs, viewer key, or running desktop user unit; install the scoped roster source and observe all three hosts in the paired viewer. r[onix.meshtop.reachable-view.live]

## Phase 4: Evidence and gates

- [x] [serial] Document the selected-route limit, operator adoption and rollback, and the three-host terminal and failure observations; run focused Nix, Nickel, whitespace, and Cairn checks. r[onix.meshtop.reachable-fleet.offline] r[onix.meshtop.reachable-view]
