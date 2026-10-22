# Use upstream Niri on Aspen3

## Phase 1: Source and consumers

- [x] [serial] Point the Niri flake and lock to upstream, remove the fork-specific package override, and migrate compositor, gesture, and sticky-window consumers. r[onix.niri.upstream.source]
- [x] [serial] Select the upstream session launcher in Aspen3's greeter configuration. r[onix.niri.upstream.aspen3]

## Phase 2: Configuration compatibility

- [x] [serial] Remove fork-only KDL settings, keybindings, and the unused raw-binding group. r[onix.niri.upstream.config]
- [x] [serial] Build and run upstream Niri, validate the Aspen3 config with the initial Noctalia include, and run the existing palm-rejection check. r[onix.niri.upstream.config.initial]

## Phase 3: Lifecycle gates

- [x] [serial] Verify remaining host selection, document the migration and rollout boundary, and run Cairn validation. r[onix.niri.upstream.aspen3.selection]

## Phase 4: Aspen3 deployment

- [x] [serial] Deploy Aspen3 through Clan and verify the active generation, upstream profile executable, and activated KDL. r[onix.niri.upstream.aspen3]
- [x] [serial] Restart greetd with the pinned upstream launcher and stop the stale fork-based compositor before the next graphical login. r[onix.niri.upstream.aspen3.selection]
