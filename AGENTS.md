# Agent Notes

## Clan deploys
- Bare `aspen1` is not reliably resolvable from managed hosts. Use `aspen1.local` for SSH deploy targets and runtime/cache URLs (`root@aspen1.local`, `http://aspen1.local:5000`, Lemonade API bases) unless a specific network path requires another name.
- On this workstation, `clan machines update ...` can lose vars generator `finalScript` store paths to local auto-GC mid-run (`/nix/store/...-generator-...: No such file or directory`). If that happens, rerun the deploy with `NIX_CONFIG=$'min-free = 0\nmax-free = 0'` so the generator script survives long enough to execute.
- Changing a vars generator's output does not automatically rewrite already-generated shared vars. If a deploy still sees stale generator content, run `clan vars generate <machine> --generator <name> --regenerate` first, then deploy again so the updated secret files are synchronized.
- Removed vars-generator outputs can linger too. After switching a generator from one output file shape to another (for example `env-file` -> `auth-json`), manually delete orphaned `vars/shared/<generator>/...` files that the new generator no longer declares.
- Unset clan prompt secret files can decrypt to the stock SOPS placeholder text `Welcome to SOPS! Edit this file as you please!` rather than an empty string. Treat that placeholder as "unset" when auditing or migrating vars.
- `vars/shared/.../secret` files are stored as raw secret blobs (`{"data": "ENC[...]", ...}`), not schema-aware JSON payloads. If you hand-edit a structured secret like `auth-json`, re-encrypt the whole plaintext file with `sops encrypt --input-type binary --output-type json ...`; encrypting nested JSON fields makes `sops-install-secrets` fail with `error emitting binary store: no binary data found in tree`.

## AI services
- On `britton-desktop`, Docker `--gpus=all` currently fails for OCI containers with `failed to discover GPU vendor from CDI: no known GPU vendor found`. Use CPU images for Infinity/Speaches until the NVIDIA container runtime/CDI setup is fixed.
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
- `britton-desktop` currently has a manual `~/.cargo/config.toml` outside this repo with `target-dir = "/home/brittonr/.cargo-target"`, `net.retry = 3`, and `term.quiet = false`. Any declarative Rust cache change should preserve or explicitly migrate that compatibility surface instead of assuming stock Cargo defaults.
- `SCCACHE_IGNORE_SERVER_IO_ERROR=1` on stock `sccache` is not enough for dead-transport startup/connect failures like a broken `SCCACHE_SERVER_UDS`; `sccache rustc -vV` can still abort before local fallback. For Home Manager Cargo rollouts here, use an outer rustc-wrapper that can detect those transport failures and exec real `rustc` directly.
