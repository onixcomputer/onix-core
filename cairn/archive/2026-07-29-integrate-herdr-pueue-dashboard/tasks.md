## Phase 1: Herdr compatibility

- [x] [serial] Update the existing `llm-agents` lock input through Nix so `britton-desktop` selects popup-compatible Herdr. r[onix.britton-desktop.herdr.pueue.version]
- [x] [serial] Preserve the existing `llm-agents` package boundary and avoid a second Herdr source. r[onix.britton-desktop.herdr.pueue.version]

## Phase 2: Typed Pueue bindings

- [x] [serial] Add typed popup and split chords to the shared Herdr keymap. r[onix.britton-desktop.herdr.pueue.bindings]
- [x] [serial] Add the local Pueue plugin source and both action IDs to the Nickel Herdr profile. r[onix.britton-desktop.herdr.pueue.bindings]
- [x] [serial] Render Pueue commands with the existing pure profile-data transformation. r[onix.britton-desktop.herdr.pueue.bindings]
- [x] [serial] Keep plugin registration out of Nix and Home Manager activation. r[onix.britton-desktop.herdr.pueue.ownership]

## Phase 3: Validation

- [x] [serial] Add positive checks for the minimum Herdr version and both rendered action IDs. r[onix.britton-desktop.herdr.pueue.validation]
- [x] [serial] Add a negative check that rejects an invalid Pueue action ID. r[onix.britton-desktop.herdr.pueue.validation]
- [x] [serial] Build the focused Herdr Pueue check and evaluate `britton-desktop`. r[onix.britton-desktop.herdr.pueue.validation]
- [x] [serial] Run the change gates and record the unrelated full-validation blocker. r[onix.britton-desktop.herdr.pueue.validation]
