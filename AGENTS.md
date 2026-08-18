# Agent Notes

## Cairn lifecycle
- Use native Cairn lifecycle artifacts under `.cairn/` for planning and change tracking in this repo. Do not create or update OpenSpec artifacts unless the user explicitly asks for migration/compatibility work.
- Use `/home/brittonr/git/cairn` as the local Cairn source checkout. It should authenticate to the canonical project `https://github.com/OnixResearch/cairn` via the SSH remote `git@github.com:OnixResearch/cairn.git`.
- Validate with `nix run path:/home/brittonr/git/cairn#cairn -- validate --root /home/brittonr/git/onix-core --policy /home/brittonr/git/cairn/cairn-policy/generated/cairn-policy.json`.

## Clan deploys
- Bare `aspen1` is not reliably resolvable from managed hosts. Use `aspen1.local` for SSH deploy targets and runtime URLs (`root@aspen1.local`, Lemonade API bases) unless a specific network path requires another name. Harmonia's extra substituter is one such exception: use `http://100.100.103.95:5000` so nix-daemon does not depend on mDNS.
- On this workstation, `clan machines update ...` can lose vars generator `finalScript` store paths to local auto-GC mid-run (`/nix/store/...-generator-...: No such file or directory`). If that happens, rerun the deploy with `NIX_CONFIG=$'min-free = 0\nmax-free = 0'` so the generator script survives long enough to execute.
- Changing a vars generator's output does not automatically rewrite already-generated shared vars. If a deploy still sees stale generator content, run `clan vars generate <machine> --generator <name> --regenerate` first, then deploy again so the updated secret files are synchronized.
- Removed vars-generator outputs can linger too. After switching a generator from one output file shape to another (for example `env-file` -> `auth-json`), manually delete orphaned `vars/shared/<generator>/...` files that the new generator no longer declares.
- Unset clan prompt secret files can decrypt to the stock SOPS placeholder text `Welcome to SOPS! Edit this file as you please!` rather than an empty string. Treat that placeholder as "unset" when auditing or migrating vars.
- `vars/shared/.../secret` files are stored as raw secret blobs (`{"data": "ENC[...]", ...}`), not schema-aware JSON payloads. If you hand-edit a structured secret like `auth-json`, re-encrypt the whole plaintext file with `sops encrypt --input-type binary --output-type json ...`; encrypting nested JSON fields makes `sops-install-secrets` fail with `error emitting binary store: no binary data found in tree`.
- If `clan machines update ... --upload-inputs` fails in `nix flake archive --to ssh://...` with `sized: unexpected end-of-file`, check the named source path with `nix-store --verify-path`. Legacy `ssh://` store copying can hide the real `hash mismatch importing path` when a local fixed-output flake input was modified/corrupted. Clean any invalid partial target path with `nix-store --delete --ignore-liveness`, prefetch the same locked input on the target (`nix flake prefetch github:owner/repo/rev`) so upload skips the corrupt local stream, then repair the local store as root later.

## AI services
- `britton-desktop` has no NVIDIA GPU. Its installed accelerators are two Tenstorrent Blackhole P150 cards; the AMD Granite Ridge controller is display-only. Do not select CUDA, NVIDIA container passthrough, or the Strix-Halo-specific `amd-gpu` compute tag for this host.
- For Tenstorrent debugging, start with `tt-smi`, service journals, and each service's `tt-metal-logs/generated/inspector` data. Use the official [TT-Metalium tools index](https://docs.tenstorrent.com/tt-metal/latest/tt-metalium/tools/index.html) for Inspector, `tt-triage`, Watcher, Device Print, and profiler escalation. Upstream only fully supports those tools on source builds, so source-level triage must use a checkout matching the pinned runtime.
- The Speaches container writes its Hugging Face cache as the in-container `ubuntu` user. Mount the cache directory with uid/gid `1000:1000` or model preloading fails with `PermissionError` under `/home/ubuntu/.cache/huggingface/hub`.
- `modules/hermes-gateway` syncs clan-var Matrix secrets into `~/.hermes/.env` at service start. Do not set `TERMINAL_CWD` in the systemd environment; Hermes warns that env var is deprecated, so set `terminal.cwd` in `~/.hermes/config.yaml` instead.
- The Hermes gateway unit carries `HERMES_GATEWAY_MATRIX_SETTINGS_HASH` for non-secret Matrix settings so allowlist/config changes restart the service and resync `.env`. Updating only the deployed secret `env-file` can leave a running gateway stale until the service restarts.
- Hermes Matrix E2EE needs the module's overridden `hermes-agent` with `python-olm`/mautrix crypto deps. Because `olm` is marked insecure, `enableEncryption = true` intentionally requires explicit `acceptInsecureLibolm = true`.

## Flake evaluation
- `nix flake show --all-systems` fails in this repo unless you pass `--option allow-import-from-derivation true`; the `wasm-plugins` checks evaluate nix-wasm plugin derivations during flake evaluation.

## Packaging
- `pkgs/lemonade/default.nix` must accept either `lemond` or `lemonade-router` as the daemon binary name. Upstream changed names across releases, so install both aliases for compatibility.

## Niri
- The `calling import-environment without specifying desired variables is deprecated` startup message comes from upstream `resources/niri-session` (`systemctl --user import-environment`). In this repo, greetd launches `/etc/profiles/per-user/brittonr/bin/niri-session`, so that warning is session-wrapper noise, not proof that `niri.service` crashed.
- `niri: Page flip commit failed on device ... (Permission denied)` immediately before a boot boundary can be compositor shutdown fallout after DRM master is lost during reboot. Check for surrounding `systemd[1]: Stopping ...` lines before treating it as root cause.

## Wrapped tool wrappers
- Helix wrapper packages from `inputs.wrappers.wrapperModules.helix.apply` keep command bindings in the generated `XDG_CONFIG_HOME` store config referenced by the wrapper script, not inside the final wrapper package root. For integration checks, inspect both the wrapper script (`bin/hx` / `bin/zen`) and the exported config store path.

## Rust workstation config
- `britton-desktop` manages `~/.cargo/config.toml` through the `inventory/home-profiles/brittonr/kache` Home Manager profile. Preserve `target-dir = "/home/brittonr/.cargo-target"`, `net.retry = 3`, and `term.quiet = false` when changing that profile.
- Build storage on `britton-desktop` is ZFS-backed and quota-limited: `datapool/cargo-target` mounts at `~/.cargo-target`, `datapool/git` mounts at `~/git`, and interactive Kache data uses `/var/cache/kache-nix/user-brittonr`. Keep repo-local `CARGO_TARGET_DIR=target` outputs under `~/git`; do not create new sibling `~/.cargo-target-*` paths unless isolation cannot use the Git dataset.
- `machines/britton-desktop/build-storage.nix` removes ignored Cargo targets only after 21 days without modified files and skips cleanup while Cargo or rustc is active. Preserve the `CACHEDIR.TAG` and Git-ignore safeguards when changing retention.
- `SCCACHE_IGNORE_SERVER_IO_ERROR=1` on stock `sccache` is not enough for dead-transport startup/connect failures like a broken `SCCACHE_SERVER_UDS`; `sccache rustc -vV` can still abort before local fallback. For Home Manager Cargo rollouts here, use an outer rustc-wrapper that can detect those transport failures and exec real `rustc` directly.
