## Phase 1: Measure and choose

- [x] [serial] Measure aspen3's pool, datasets, snapshots, directory sizes, entry counts and open holders; confirm cross-dataset block cloning; record Britton's sizes and his choice to move the busy directories at the next reboot. r[onix.aspen3.storage.disposable] r[onix.aspen3.storage.agents] r[onix.aspen3.storage.reservations]

## Phase 2: Implement

- [x] [serial] Add `machines/aspen3/storage.nix` with the dataset list, gated mounts, boot-time migration, property enforcement and cleanup jobs, and import it. r[onix.aspen3.storage.disposable] r[onix.aspen3.storage.agents] r[onix.aspen3.storage.reservations] r[onix.aspen3.storage.properties] r[onix.aspen3.storage.migration] r[onix.aspen3.storage.cargo_cleanup] r[onix.aspen3.storage.garbage]
- [x] [serial] Correct the `/nix` quota comment in `machines/aspen3/configuration.nix`. r[onix.aspen3.storage.reservations]

## Phase 3: Deploy and verify

- [x] [serial] Build and switch aspen3; verify datasets, properties, reservations, skipped mounts and timers. Generation 126 (`dzqq9d53`) switched with exit 0; the migration service reported that it waits for boot, all six mounts were skipped on their conditions, `/nix` reserves 162G and `/` 106G, the first cleanup run removed 39 stale scratch GC roots, and the first Cargo prune removed `~/.cargo-target/tmp`; see verification.json. r[onix.aspen3.storage.properties] r[onix.aspen3.storage.migration] r[onix.aspen3.storage.cargo_cleanup] r[onix.aspen3.storage.garbage]
- [x] [serial] Move `~/.claude` live and verify its mount, marker and copy (15 entries, 1327452 bytes, identical to `~/.claude.pre-zfs`). The live run refused `~/.cargo-target`: two rust-analyzer proc-macro servers map libraries from it, so it moves at the next boot with the rest. r[onix.aspen3.storage.migration] r[onix.aspen3.storage.disposable]
- [x] [serial] After Britton's reboot, verify all six mounts, the 40 GiB `zroot/agents` reservation and the migration journal. The 2026-11-19 12:35 EST boot moved all five pending directories in 3 min 47 s, each with matching entries and bytes; see verification.json. r[onix.aspen3.storage.migration] r[onix.aspen3.storage.agents]
- [x] [serial] Delete the six `.pre-zfs` originals. Deleted on 2026-11-19 at 18:21Z with Britton's approval under a self-posted claim (Kiln refused while #147, #152, #156 and #158 lacked referenced releases). Each was checked first: its directory mounted from its dataset with its marker, no holder, nothing written since the boot. `/home` referenced dropped from 596.5 GiB to 499.4 GiB. r[onix.aspen3.storage.migration]
