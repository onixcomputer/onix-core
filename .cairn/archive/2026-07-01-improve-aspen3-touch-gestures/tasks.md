## Phase 1: Configure touch input

- [x] [serial] Add typed touchpad scroll/tap/middle-emulation settings and render them into Niri. r[onix.aspen3.touch.niri]
- [x] [serial] Add Niri drag-and-drop workspace edge switching. r[onix.aspen3.touch.niri]
- [x] [serial] Move `lisgd` touchscreen bindings into typed Nickel data and render them safely from Nix. r[onix.aspen3.touch.lisgd]

## Phase 2: Validate

- [x] [serial] Validate Nickel gesture/input data exports. r[onix.aspen3.touch.verification]
- [x] [serial] Evaluate or build the focused `aspen3` system path so Niri config validation runs. r[onix.aspen3.touch.verification]
- [x] [serial] Run Cairn validation and gates for this change. r[onix.aspen3.touch.verification]

## Phase 3: Live troubleshooting

- [x] [serial] Fix touchscreen discovery to match libinput's whitespace-delimited `touch` capability on aspen3. r[onix.aspen3.touch.lisgd]
- [x] [serial] Retrigger stale udev input metadata so ELAN9008 event nodes are tagged as touchscreen/tablet. r[onix.aspen3.touch.verification]
