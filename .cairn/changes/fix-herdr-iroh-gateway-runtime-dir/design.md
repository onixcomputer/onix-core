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

## Completion State

onix-core `c48db873` published the change. Buildbot's `nix-eval` passed; its
`nix-build` checks failed on every system, as they did on the parent commit
`69176d76`.

britton-desktop runs generation 881, system
`h129gwvdnmvkly47ms7353pvf41xi7p8`, built from the deployed source
`/nix/store/wc9c89si6dlmrjxqf61njhif6zx5zpiy-source` (GC root
`~/.local/state/onix-core/deployments/881/source`). That source differs from
generation 880's only in `inventory/tags/common/herdr-iroh.nix`. aspen3 runs
generation 105, system `799i1465kcp2rmcv02gbyp0clzfc5vkj`. On both hosts the
closure changed by 4 paths each way (`etc`, `system-units`, the herdr-iroh
unit and the system itself), the unit gained only
`Environment="XDG_RUNTIME_DIR=/run/user/1555"`, and `dry-activate` and the
switch stopped and started only `herdr-iroh.service`. britton-desktop's switch
reported the units generation 880 also reported (`celld`, `celld-site`,
`collie-serve`, `llamacpp-server-supra-router`, `home-manager-brittonr`);
aspen3's reported `celld` and `celld-site`, which were already restarting in a
loop.

The relays run with `XDG_RUNTIME_DIR=/run/user/1555` in their environment:
britton-desktop PID 1506222 with endpoint
`fd84a45387385d77e9ce2f5fa92548c42e412bbe54e83c18e441065bea30d115`, aspen3 PID
3267480 with endpoint `700c67336e74…`, both with unchanged key hashes. Herdr
server PIDs 4940 (britton-desktop, 24 children) and 206029 (aspen3, 8
children) kept their identities. Through aspen3's gateway, Grok's herdr
connector pinged britton-desktop, `cproof-brittonr` and `instantfill-vm`
successfully, and britton-desktop reached aspen3 in reverse.

At 04:56 on 2026-11-08, a deploy from britton-desktop's `~/git/onix-core`
(local `main` at `08f9b24e` with uncommitted changes, without this commit and
with herdr-iroh locked to `1ee15bf8`) switched aspen3 to generation 106,
system `1pvkqmklsa1f527a3sc4yz4xmi2xqxpb`. That relay runs without
`XDG_RUNTIME_DIR` again. Deploy aspen3 from a tree that contains this commit
to restore it.
