## Phase 1: Package and core behavior

- [x] [serial] Package all seven fixed plugin roots and their required runtime binaries. r[onix.britton-desktop.herdr.wrapper.plugins]
- [x] [serial] Add the pure static-registry merge and the environment-backed loading shell to Herdr. r[onix.britton-desktop.herdr.wrapper.registry]
- [x] [serial] Build the Herdr wrapper and select it in the `britton-desktop` system package list. r[onix.britton-desktop.herdr.wrapper.install]

## Phase 2: Profile and evidence

- [x] [serial] Remove the manual synchronization surface while preserving typed actions and mutable user state. r[onix.britton-desktop.herdr.wrapper.ownership]
- [x] [serial] Add positive and negative checks, run the focused builds, and validate the Cairn change. r[onix.britton-desktop.herdr.wrapper.validation]
