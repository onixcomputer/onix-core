## Why

herdr-iroh `1ee15bf8506a13394de2f253ee6fd8febfca1a64` reads `agent_session`,
`cwd` and `name` from `result` of Herdr's `agent.get` reply. Herdr protocol 22
answers `{"type":"agent_info","agent":{...}}`, so against a running Herdr every
`relay.agent_session` call reported "agent kind is not omp", `relay.answer`
never found a pending ask, and status webhooks lost their cwd and recap. The
upstream test double used the same wrong flat shape, so its suite passed.
herdr-iroh `a342b855dbd6483fe6407baba69d28ecdac71501` reads those fields from
`result.agent` and makes the double answer in protocol 22 shapes.

## What Changes

- Lock herdr-iroh to `a342b855dbd6483fe6407baba69d28ecdac71501`. No other input
  moves: the `flake.lock` delta is limited to the herdr-iroh node.
- Rebuild britton-desktop from its recorded deployed source with only the same
  pin change, and switch only after `diff-closures` and `dry-activate` show the
  relay as the only changed package. The running Herdr server and its agents
  must keep running; only `herdr-iroh.service` restarts.
- Record aspen3 as already running the fix. It switched to generation 104 on
  2026-11-07, built from the same deployed source with a local
  `--override-input herdr-iroh git+file` at `a342b855` before publication.
  Confirm its relay package equals the one built from the published pin.

## Impact

Endpoint keys, allowlists and the rendered `server.toml` are unchanged, and no
port opens. aspen1 and aspen2 keep their running relays until their next deploy
from main. The change does not address the bot box's MCP connector failing to
load (`failed_to_load`), which happens before any relay call is made.

## Affected Specs

- `herdr-saved-machine-gateway`: the pin requirement moves to `a342b855` and
  covers aspen3; a new requirement covers reading Herdr's `AgentInfo` reply.
