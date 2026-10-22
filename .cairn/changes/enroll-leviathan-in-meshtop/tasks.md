# Leviathan Meshtop enrollment tasks

## Selected external agent

- [x] [serial] Verify strict noninteractive SSH access and that Leviathan is outside onix-core's machine inventory. r[onix.meshtop.leviathan-agent]
- [x] [serial] Build and install the pinned published Meshtop source on Leviathan without relaxing its Nix store trust, and install the selected user-unit template. r[onix.meshtop.leviathan-agent.selected]
- [x] [serial] Keep the new agent key on Leviathan with owner-only permissions, authorize the existing desktop viewer, and record only the observed public agent ID. r[onix.meshtop.leviathan-agent.selected]

## Desktop four-host view

- [x] [serial] Append the observed Leviathan ID to the Home Manager roster without changing the three existing IDs or keys; render and select only the generated roster, retaining its GC root. r[onix.meshtop.leviathan-view]
- [x] [serial] Observe the authorized four-host one-shot sample, navigate the narrow live dashboard to Leviathan's CPU and unavailable GPU readings, and confirm an unpaired viewer receives no telemetry. r[onix.meshtop.leviathan-view.live] r[onix.meshtop.leviathan-view.auth]
- [x] [serial] Record the scoped rollout, repeatable source/build path, ownership, authentication and GPU non-claims in onix-core documentation. r[onix.meshtop.leviathan-view] r[onix.meshtop.leviathan-agent.linger]

## User-manager continuity

- [x] [serial] Confirm the enabled active user unit and `Linger=no`; record the operator's acceptance of session-only operation without claiming post-logout or boot continuity. An authorized Leviathan administrator must enable lingering before that claim changes. r[onix.meshtop.leviathan-agent.linger]
