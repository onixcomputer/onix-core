## Phase 1: Configure idle behavior

- [x] [serial] Add an opt-out for the Noctalia `swayidle` suspend timeout while preserving dimming and DPMS behavior. r[onix.aspen3.power.idle]
- [x] [serial] Disable Noctalia idle auto-suspend for `aspen3`. r[onix.aspen3.power.idle]
- [x] [serial] Ignore lid-close sleep for docked/external-power `aspen3` operation while preserving battery defaults. r[onix.aspen3.power.lid]

## Phase 2: Validate

- [x] [serial] Evaluate focused `aspen3` configuration and confirm its `swayidle` command omits `systemctl suspend`. r[onix.aspen3.power.verification]
- [x] [serial] Run a contrast check proving the shared Noctalia default still includes the suspend timeout when the option remains enabled. r[onix.aspen3.power.verification]
- [x] [serial] Run Cairn validation and gates for the change. r[onix.aspen3.power.verification]
