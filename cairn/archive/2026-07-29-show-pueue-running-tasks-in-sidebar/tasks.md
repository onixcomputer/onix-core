# Tasks: Render running Pueue tasks in Herdr

## Phase 1: Typed configuration

- [x] [serial] C1 Raise the managed Pueue compatibility floor to Herdr `0.7.5`. r[onix.britton-desktop.herdr.pueue.version]
- [x] [depends:onix.britton-desktop.herdr.pueue.sidebar_overview] C2 Add typed Space rows for status and two running-task tokens. r[onix.britton-desktop.herdr.pueue.sidebar_overview]

## Phase 2: Validation

- [x] [depends:onix.britton-desktop.herdr.pueue.sidebar_overview] V1 Require the three safe Pueue tokens in the generated TOML. r[onix.britton-desktop.herdr.pueue.sidebar_overview]
- [x] [depends:onix.britton-desktop.herdr.pueue.sidebar_overview] V2 Reject an environment token and preserve the activation ownership checks. r[onix.britton-desktop.herdr.pueue.sidebar_overview]
- [x] [depends:onix.britton-desktop.herdr.pueue.sidebar_overview] V3 Run Nickel evaluation, the focused Nix check, system evaluation, and Cairn gates. r[onix.britton-desktop.herdr.pueue.sidebar_overview]

## Evidence

The focused `herdr-pueue-dashboard` check passes with all three safe custom tokens and the negative environment-token check. The generated TOML passes `herdr config check`, and `britton-desktop` evaluates to a system derivation.
