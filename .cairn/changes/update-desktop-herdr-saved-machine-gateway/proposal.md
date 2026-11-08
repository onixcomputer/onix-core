## Why

Britton requested the saved-machine gateway from herdr-iroh main commit
`1ee15bf8506a13394de2f253ee6fd8febfca1a64` on britton-desktop. The serve
process needs a compatible Herdr CLI and SSH, and must actually restart onto
its new executable. The existing Herdr server and its many agents must remain
running; no server.stop or live handoff is permitted.

## What Changes

- Publish the shared relay configuration for its existing five-host fleet and
  lock herdr-iroh to the requested commit. Deploy only britton-desktop here.
- Set upstream `services.herdr-iroh.herdrPackage = pkgs.herdr`; the module writes
  `herdr_bin` and supplies Herdr/OpenSSH on the serve unit PATH. Keep the gateway
  enabled by its upstream default and preserve peer authorization/state.
- Leave the `[notify]` webhook section unset; this rollout adds no webhook
  endpoint or notification credential.
- Retain the existing compatible Herdr 0.9.3 pin rather than attempting an
  unnecessary package upgrade; the running desktop CLI already reports 0.9.3.
- Keep the public commit gateway-only. Build and deploy a gateway-only copy
  of the recorded deployed source and input cohort, avoiding unrelated
  unpublished changes or package rollbacks. Mirror only the gateway edits
  and its targeted lock update into the primary checkout.
- Build, commit, push, then run the repository's Clan machine-update command.
  Abort if its exact preview would restart or replace the existing Herdr server.
- Prove the relay process executes the new binary, then run the requested
  `herdr --machine instant-fill status server` command exactly once and report
  its result and deployed versions.

## Impact

The existing dirty/diverged primary checkout is not bundled into the release.
Of Herdr processes, only the relay may restart. The exact NixOS preview also
restarts polkit and reloads dbus-broker; it does not replace the Herdr server
or the admitted Qwen unit. Secret-key bytes, server sessions, agent processes,
and unrelated service attachments must not change. Gateway access retains
its existing allowed-peer policy and does not open a new firewall port.

## Affected Specs

- `herdr-saved-machine-gateway`: release, executable selection, restart and
  preservation requirements for this desktop rollout.
