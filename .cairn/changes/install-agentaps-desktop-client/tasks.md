## Phase 1: Package and pin

- [x] [serial] Add `pkgs/agentaps` to onixpkgs pinned to upstream `9d526af`, build it, check its library resolution, and launch it headlessly. r[onix.agentaps.source]
- [x] [serial] Publish onixpkgs `main` to `origin` and `rad`, then relock onix-core's `onixpkgs` input without adding a flake input. r[onix.agentaps.source.overlay]

## Phase 2: Wiring

- [x] [serial] Add `agentaps` to `brittonr`'s Home Manager packages on `britton-desktop` and `aspen3`, keeping the existing entries. r[onix.agentaps.install]
- [x] [serial] Port the addition onto `britton-desktop`'s deployed lineage, taking the package from the onixpkgs `packages` output. r[onix.agentaps.source.desktop_lineage]

## Phase 3: Verification

- [x] [serial] Evaluate both machines' `brittonr` package lists for `agentaps` and the existing entries. r[onix.agentaps.install.selected] r[onix.agentaps.install.preserve_existing]
- [x] [serial] Build both toplevels and compare each closure with the running system. r[onix.agentaps.deployment] r[onix.agentaps.deployment.lineage]
- [x] [serial] Run Cairn validation and the proposal, design, and tasks gates. r[onix.agentaps.install]

## Phase 4: Deployment

- [x] [serial] Deploy `britton-desktop` and `aspen3`. r[onix.agentaps.deployment]
- [x] [serial] Resolve `agentaps` on `brittonr`'s `PATH` on both hosts and record the evidence. r[onix.agentaps.deployment.path]

### Deployment evidence (2026-09-28)

- `britton-desktop`: `/run/current-system` is `0q2rfhnmzvkf807xcrajwqkbhb4b6z11`; `fish -lc 'command -s agentaps'` resolves `/etc/profiles/per-user/brittonr/bin/agentaps` to packaged executable `95qfqyfz07dxwmdgaymg6vx290gm8vnl`. The installed executable rendered the Agentaps project picker on headless Sway.
- `aspen3`: `/run/current-system` is `lv1ybqglkg0phrj15vy6gybw08fvrhjl`; `brittonr`'s fish and Bash login shells both resolve `/etc/profiles/per-user/brittonr/bin/agentaps` to packaged executable `jc01nifcydh747nzw2l9f5vc5kc8hbcj`. Launched as `brittonr` on the running Niri session, the process remained alive and Niri reported a window titled `Agentaps`.
- The aspen3 candidate was compared against its running closure before activation: 33 added and 31 replaced paths, with no package removal or downgrade; the onixpkgs bump upgrades `iroh-ssh` from 0.2.9 to 0.2.12. Clan's remote SSH copy and secret-sync steps failed on the intermittent tailnet link. The built onix-core candidate was imported, rooted, and activated directly without replacing secrets. Activation reported status 4 for the existing celld storage failures, but `/run/current-system` reached the candidate and Home Manager is active.
- The desktop switch reached its candidate and installed Agentaps, but Home Manager activation hit the pre-existing hand-installed `collie.service` versus managed-unit conflict; the hand-installed unit was left untouched.
