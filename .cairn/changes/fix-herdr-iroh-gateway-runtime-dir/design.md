## Baseline and Scope

britton-desktop runs generation 880 from deployed source
`/nix/store/7lkwa6ddjgisxkdghwvpwnrr5b5b94w4-source`; aspen3 runs generation
104, the same system that source produces for aspen3. Both relays run
herdr-iroh `a342b855` as `brittonr` (uid 1555) with `Linger=yes`, and the unit
environment holds only `LOCALE_ARCHIVE`, `PATH` and `TZDIR`.

Reproduction on aspen3 with the same herdr binary and no
`XDG_RUNTIME_DIR`: `herdr --machine britton-desktop status server` exits 1
with `vdollar_percent_expand: env var ${XDG_RUNTIME_DIR} has no value` and
`/home/brittonr/.ssh/config line 52: Invalid environment expansion`. With
`XDG_RUNTIME_DIR=/run/user/1555` it reports `status: running`, version 0.9.0,
protocol 22.

## Decisions

Set the variable on the unit in the shared herdr-iroh tag, where the fleet's
relay user is chosen, rather than in the upstream module or the user's ssh
config. The ssh config is shared by every login and should stay as it is, and
the module cannot know which variables a user's ssh config expands. Derive the
path from `users.users.<user>.uid` instead of repeating 1555;
`inventory/tags/media.nix` hard-codes the same directory for mpd.

Deploy the same way as `fix-herdr-iroh-agent-session-reads`: copy the
recorded deployed source, apply this one change, and switch after reviewing
the closure diff, the unit diff and `dry-activate`.

## Verification

Require the unit diff to add only `XDG_RUNTIME_DIR`, the closure diff to touch
only the unit and the files that reference it, and `dry-activate` to restart
only `herdr-iroh.service`. After switching, require the relay's environment to
contain the variable, an unchanged endpoint ID and key hash, and Grok's
forwarded pings to the saved machines to succeed.
