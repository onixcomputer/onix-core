## Phase 1: Implementation

- [x] [serial] Package the local Tailscale-to-SSH updater with assigned-name, offline-node and ambiguity handling. r[onix.ssh.tailscale.discovery]
- [x] [serial] Add atomic private-file refresh and last-good preservation across failures. r[onix.ssh.tailscale.refresh]
- [x] [serial] Wire the runtime include and scheduler into the existing Home Manager SSH profile. r[onix.ssh.tailscale.schedule]
- [x] [serial] Remove stale copied Tailscale addresses while retaining explicit SSH identity and LAN/root policy. r[onix.ssh.tailscale.policy]

## Phase 2: Verification and scoped activation

- [x] [serial] Run focused regressions and actual OpenSSH override/alias checks. r[onix.ssh.tailscale.policy.precedence]
- [x] [serial] Exercise real local discovery, unchanged-file and failed-refresh transitions. r[onix.ssh.tailscale.refresh.transitions]
- [x] [serial] Build and activate only the selected SSH updater/config/scheduler artifacts on Britton and Aspen3. r[onix.ssh.tailscale.schedule.live]
- [x] [serial] Verify both active schedulers and machine-specific aliases, document usage, and record native Cairn validation. r[onix.ssh.tailscale.schedule.live]
