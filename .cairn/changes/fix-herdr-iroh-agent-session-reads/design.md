## Baseline and Scope

herdr-iroh `main` moved from `1ee15bf8` to `a342b855` by fast-forward on
2026-11-08. The fix changes `src/serve.rs` to read `result.agent` and
`tests/agents.rs` to answer `agent.get` and `agent.prompt` in Herdr's protocol
22 `success_response` shapes. With the corrected double,
`session_prompt_and_answer_use_the_reported_omp_file` fails on `1ee15bf8`
("agent kind is not omp") and passes on `a342b855`; all 37 tests pass, and
rustfmt and clippy (`-D warnings`) are clean.

Live check on aspen3 against Herdr 0.9.3 (protocol 22) through a temporary
relay with its own key and allowlist: `relay.agent_session` for an omp pane
returned `supported: false` ("agent kind is not omp") with `1ee15bf8`, and
`supported: true` with 8 messages, 12 tool calls and 1 todo with `a342b855`.

britton-desktop runs generation 879, system
`6pps2zpn1c6jv804ir6nsy8nmr4nvc05`, built from the deployed source
`/nix/store/gzmxdll7sbhrdrj4424flncq17vldwkk-source` (GC root
`~/.local/state/onix-core/deployments/879/source`). Its relay is PID 1203837 on
`66razj6rddvlgf9csi1wnkyryb4yxbmb-herdr-iroh-0.1.0` (`1ee15bf8`). Its Herdr
server is PID 4940, started 2026-10-23.

aspen3 runs generation 104, system `hb0pxkclkn415149h2sqfgkl5aipjbq0`: the
same deployed source with herdr-iroh overridden to `a342b855` from a local
`git+file` checkout before publication, relay package
`nbrxnkk2ndjm20rrzpzpqg7n52g90d3q-herdr-iroh-0.1.0`.

## Decisions

Main and the deployed source receive the same `flake.nix` line and herdr-iroh
lock node. Main's lock predates the deployed input cohort, so deploying main
would roll back unrelated packages, as recorded in
`update-desktop-herdr-saved-machine-gateway`.

Activate with `nix-env --set` and `switch-to-configuration switch` over root
SSH after reviewing `nix store diff-closures` and `dry-activate`, the path
used for aspen3 generation 104. No vars change, so Clan's vars upload adds
nothing. Record the new deployed source as a GC root under
`~/.local/state/onix-core/deployments/<generation>/source`.

Stop and report if `dry-activate` would stop or restart anything beyond
`herdr-iroh.service`, `polkit.service` and a `dbus-broker` reload, or if the
closure diff contains anything but herdr-iroh.

## Verification

Check that the `flake.lock` delta is limited to the herdr-iroh node. On
britton-desktop, record the relay PID and executable, the Herdr server PID and
its children, and the relay key hash before switching; afterwards require the
new executable, unchanged endpoint ID and key hash, and unchanged Herdr
processes. Exercise the deployed binary against britton-desktop's Herdr with a
temporary relay that has its own key and allowlist, and require
`relay.agent_session` to report `supported: true` for a live omp pane. Require
an unlisted peer to be refused by the production relay. Evaluate aspen3 from
the published-pin source and compare its relay package with the running one.

## Completion State

herdr-iroh `a342b855` is on `main`; its CI run 42440685146 passed (tests,
clippy, rustfmt and `nix build`). onix-core `65fbb7d7` published the pin.
Buildbot's `nix-eval` passed; its `nix-build` checks failed on every system,
as they did on the parent commit `9c4933c6`.

britton-desktop runs generation 880, system
`ic2zr0f8syzqsskcai49q6043chcpyp3`, built from the deployed source
`/nix/store/7lkwa6ddjgisxkdghwvpwnrr5b5b94w4-source` (GC root
`~/.local/state/onix-core/deployments/880/source`). That source differs from
generation 879's only in `flake.nix` and `flake.lock`; the copy it was made
from had generation 879's recorded NAR hash before the edit. The closure
changed by 17 paths each way: herdr-iroh, its unit, and the system wrappers
that reference them. `dry-activate` and the switch both stopped and started
`herdr-iroh.service` and `polkit.service` and reloaded `dbus-broker`. The
switch exited 4 for `celld`, `celld-site`, `collie-serve`,
`llamacpp-server-supra-router` and `home-manager-brittonr` (the
`meshtop.service` clobber check), the units the generation 879 switch also
reported.

The relay is PID 3083426 on
`nbrxnkk2ndjm20rrzpzpqg7n52g90d3q-herdr-iroh-0.1.0`, with endpoint
`fd84a45387385d77e9ce2f5fa92548c42e412bbe54e83c18e441065bea30d115` and an
unchanged key hash. Herdr server PID 4940 and its 24 children kept their
identities. The production relay refused an unlisted key. A temporary relay on
the deployed binary, with its own key and allowlist, read omp pane `wC:pD`
through britton-desktop's Herdr 0.9.0 server: `supported: true`, 8 messages
and 12 tool calls.

Evaluating aspen3 from the deployed source with the published pin gives
`hb0pxkclkn415149h2sqfgkl5aipjbq0`, the system aspen3 already runs as
generation 104, so aspen3 needs no further switch.
