## Baseline and Scope

The published base is origin/main 9914d811. The primary checkout has extensive
unrelated staged/unstaged work and a separate secret-vars commit; release work
is isolated under `/home/brittonr/git/onix-core-herdr-gateway-7e7d886`.
The published source and lock predate the live desktop, including the admitted
Qwen package. Do not deploy that older base or import unrelated unpublished
source into main. The retained deployed-input snapshot
`/nix/store/72nlf71zz0pnr6mm47yfd8yjnllw1wpp-source/flake.lock` has SHA256
`a6ef40bcfc1a22946faab0fd1bcdeac842c94c4550e9b92b91c0d0e951018b6e`.

The desktop starts from generation 878, system `mjlm0kyrfyb37d0jlnqw49r13h5qhigp`.
The old relay is PID 30656, executing package `xgaihyh4wxvcwq3layrnj9w0ivmdz307`
and using persistent `/var/lib/herdr-iroh`. The existing Herdr process is
PID 4940, started October 23; there is no managed Herdr server unit. The CLI
already reports 0.9.3 and exposes `--machine`. CLI and running-server versions
must not be conflated.

## Decisions

Use the upstream module's `herdrPackage` option, not a second PATH convention.
Its generated TOML contains an absolute `herdr_bin` and its service PATH includes
Herdr and OpenSSH. Leave upstream gateway=true and existing authorization/state
intact. The onixpkgs static registry is compatible with the existing 0.9.3 pin;
retain that pin and Zig 0.16 compatibility selection.

Publish only the gateway delta from the isolated release worktree. In the
primary checkout, change only its gateway URL, the shared herdrPackage option,
and the targeted lock update; preserve unrelated files and all existing staging.
The primary lock also predates the deployed cohort. Build and run Clan from a
gateway-only copy of the recorded deployed source, retaining that source's
full input cohort. This avoids both unrelated package rollbacks and deployment
of pending local work. Use its repository-provided Clan CLI with wasm-capable
Nix. Review the exact built generation before activation. Stop and report if
any step would stop, restart, or hand off the running Herdr server; preserve
the admitted model package too.

A SIGHUP is not executable replacement. Compare the relay PID/start timestamp
and `/proc/<pid>/exe` to the new selected package after Clan deployment. If Clan
only reloads it, explicitly restart herdr-iroh.service, never Herdr itself.
Preserve the service identity and verify existing server PID/start/socket.

## Verification

Build the package/system, inspect generated TOML/unit PATH and compatible CLI,
then record commit/push and Clan output. Observe an actual new relay process,
unchanged Herdr server and agents, and preserved public endpoint identity.
Only after deployment, invoke the requested saved-machine status command once;
record its stdout/stderr/exit status and versions without retrying it.

## Completion State

Source commit `878ecb57fe6718e28f15a82bad53db8726d23244` is published. Clan
completed with exit 0 on generation 879, system
`6pps2zpn1c6jv804ir6nsy8nmr4nvc05`, using the requested
`1ee15bf8506a13394de2f253ee6fd8febfca1a64` relay and Herdr CLI 0.9.3.
The running relay is PID 1203837 on the new executable. Herdr PID 4940 and all
24 captured PTY children retain their identities/start times; its socket,
the relay key, and Qwen PID 4054998 are unchanged. The rendered `[notify]`
section remains absent.

The saved-machine probe ran exactly once. It exited 2 with no stdout and:
```text
error: unknown machine 'instant-fill'; use `herdr machine list`
```

No saved profile was added and the command was not retried.

The operator-approved stuck validation worker was cancelled. A temporary
deployment-only SSH wrapper passed min-free/max-free=0 to the remote nix-env
profile command; it was removed after the verified switch. No host Nix
settings, Herdr lifecycle controls, or unrelated service attachments changed.

Clan accepted the running target after activation reported failed celld-site,
celld, collie-serve, home-manager-brittonr, and llamacpp-server-supra-router
units. Home Manager still rejects the foreign meshtop.service link. These
unrelated failures were not repaired. Canonical proposal/design/tasks gates
pass; release-worktree validation retains the incomplete Spark-change findings.
GitHub reported the required buildbot check bypass on the maintainer push;
the exact desktop build and activation scope were verified locally.

`evidence/preflight.json` records the build/preview; `evidence/rollout.json`
records the deployed executable, preservation checks, publication, and the
single probe result. The exact source is retained by the local deployment
GC root recorded there rather than publishing unrelated baseline source.
