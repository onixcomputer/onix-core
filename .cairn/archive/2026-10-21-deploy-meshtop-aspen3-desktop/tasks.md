# Deploy meshtop on Aspen3 and britton-desktop

## Phase 1: Reproducible package

- [x] [serial] Pin and import exact committed meshtop source with a repo-owned checked sync script; build the onix-core Rust package and verify its executable. r[onix.meshtop.package]

## Phase 2: Host integration

- [x] [serial] Add opt-in NixOS service with private durable agent identity and the explicitly authorized viewer ID; enable it on Aspen3 only. r[onix.meshtop.aspen3]
- [x] [serial] Declare the desktop Home Manager user agent, viewer package, and observed two-host roster; confirm other inventory hosts remain unchanged. r[onix.meshtop.desktop]

## Phase 3: Activation and live verification

- [x] [serial] Build and deploy the Aspen3 NixOS system; verify its live agent ID, systemd status, private key, and authorized read-only sample. r[onix.meshtop.aspen3]
- [x] [serial] Build the britton-desktop Home Manager generation; activate its onix-core-generated unit, roster, and package without claiming a blocked whole-system switch; verify live identity and sample. r[onix.meshtop.desktop]
- [x] [serial] Pin both observed public agent IDs in the viewer roster; exercise two-host samples, single-host-offline behavior, and unauthorized viewer denial from the deployed viewer. r[onix.meshtop.verify]

## Phase 4: Evidence and gates

- [x] [serial] Document operator commands, revision, receipt scope and rollback; run focused Nix checks and Cairn validation/gates without changing the pre-existing flake.lock edit. r[onix.meshtop.verify]

## Phase 5: Concurrent viewer panels

- [x] [serial] Pin the tested upstream host-grid revision, upgrade only the desktop viewer, observe both agent panels and metrics simultaneously at wide and narrow terminal sizes, and update operator guidance. r[onix.meshtop.desktop]

## Phase 6: Themed GPU telemetry

- [x] [serial] Pin the tested themed Meshtop revision, verify bounded AMD sysfs GPU snapshots and missing-sensor/older-agent behavior, and rebuild the onix-core package. r[onix.meshtop.gpu]
- [x] [serial] Refresh Aspen3's exact NixOS-generated agent unit through the scoped persistent control path and the desktop's linked Home Manager user unit without changing keys or claiming either whole-host system switch; verify both GPU-enabled samples and themed wide/narrow cards. r[onix.meshtop.gpu]
- [x] [serial] Record operator upgrades, unsupported-device boundary, and scoped evidence; validate the active Cairn change and diff. r[onix.meshtop.gpu]
