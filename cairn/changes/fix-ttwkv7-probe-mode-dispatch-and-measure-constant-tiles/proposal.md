## Why

The previous authorized process reached the repaired immutable production wrapper but returned status 2 before device initialization. The wrapper validated probe runtime state, shifted away the required `probe` mode, and executed the C++ binary with no mode argument. Package tests asserted only an extra forwarded argument, so they accepted this semantic loss. All fourteen exact constant masks remain unmeasured.

## What Changes

- Preserve `probe` as the first runtime-binary argument after wrapper validation.
- Validate the exact fake-target argument vector with no extra arguments and with an additional forwarded argument, while retaining actual immutable-target and no-device self-test checks.
- Rebuild the package, dual-architecture check, and full host closure without hardware access.
- Prepare a fresh executable one-shot with a unique evidence root, unused Inspector port, exact immutable inputs, independent rollback, and zero counters.
- Consume exactly one newly authorized device-1 process with no fallback or retry, restore ownership, and classify all fourteen masks or the first terminal blocker.

## Impact

- **Files**: `pkgs/ttwkv7/probe-wrapper.sh`, `pkgs/ttwkv7/runtime.nix`, and this Cairn lifecycle package; a fresh executable runbook is added after the repaired store path is known.
- **Testing**: baseline package behavior; exact positive and negative argument-vector checks; package, architecture, host-closure, formatting, ShellCheck, pre-commit, and Cairn gates; strict owner/root/timer/runtime preflights; one bounded physical process; retained restoration evidence.
- **Claims**: Even fourteen exact passes establish only the reviewed constant generators on the selected P150. They do not establish full-WKV, decode, performance, or general P150 compatibility.
