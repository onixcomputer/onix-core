# Agent Notes

## Clankers
- `self.packages.<system>.clanker-router` now tracks the upstream clankers flake package directly. Multiple remote OpenAI-compatible backends are supported upstream through `--local-provider-config`, so `modules/clankers` should use that instead of carrying a local patch.
- `modules/clankers` router settings accept `localProviders = [{ name, apiBase, models = [ ... ] }]`. The module writes `clanker-router-local-providers.json` and passes it via `--local-provider-config`.
- The daemon must talk to the router proxy through `OLLAMA_HOST`/the module's `apiBase` env wiring, not clankers' `--api-base` flag. `--api-base` only gives clankers the Anthropic-compatible surface, so it never discovers the remote Lemonade models from `/v1/models`.
- If pi shows a Lemonade-backed model selected but no visible reply appears, check the target machine's `journalctl -u lemonade`. A common failure is `request (...) exceeds the available context size`, which means the chat history is longer than the configured `contextSize` even though model lookup succeeded.
- For the new provider-scoped router OAuth seeding, `clankers auth export` / `clanker-router auth export` JSON records are the right input. Do not go back to Anthropic-only access-token prompts.
- `clan vars generate ... --regenerate` on hidden prompt-backed vars wants a TTY; in non-interactive sessions it can die with `termios.error: (25, 'Inappropriate ioctl for device')`. Use `clan vars set <machine> <service/var> < file` to update prompt secrets non-interactively, then rewrite derived `auth-json` explicitly if needed.
- `~/.codex/auth.json` can drift into a bad state where `codex login status` still reports logged in but the refresh token fails with `refresh_token_reused`; re-probe before pasting a Codex record into clan vars.
- ChatGPT-backed Codex service auth currently works with a fixed routed model set (`gpt-5.2`, `gpt-5.3-codex`, `gpt-5.3-codex-spark`, `gpt-5.4`, `gpt-5.4-mini`). Older probe targets like `gpt-5.1-codex-mini`, `gpt-5.2-codex`, or `codex-mini-latest` fail for ChatGPT accounts, and the backend probe must use `stream=true`.
- For `clan ... --build-host <machine>`, the deploy copy runs on the build host (`nix copy --to ssh-ng://root@<target>`). The build host's root account needs its own working SSH identity for the target; forwarded agents can fail with `agent refused operation` on the second hop.

## Clan deploys
- On this workstation, `clan machines update ...` can lose vars generator `finalScript` store paths to local auto-GC mid-run (`/nix/store/...-generator-...: No such file or directory`). If that happens, rerun the deploy with `NIX_CONFIG=$'min-free = 0\nmax-free = 0'` so the generator script survives long enough to execute.
- Changing a vars generator's output does not automatically rewrite already-generated shared vars. If a deploy still sees stale generator content, run `clan vars generate <machine> --generator <name> --regenerate` first, then deploy again so the updated secret files are synchronized.
- Removed vars-generator outputs can linger too. After switching a generator from one output file shape to another (for example `env-file` -> `auth-json`), manually delete orphaned `vars/shared/<generator>/...` files that the new generator no longer declares.
- Unset clan prompt secret files can decrypt to the stock SOPS placeholder text `Welcome to SOPS! Edit this file as you please!` rather than an empty string. Treat that placeholder as "unset" when auditing or migrating vars.
- `vars/shared/.../secret` files are stored as raw secret blobs (`{"data": "ENC[...]", ...}`), not schema-aware JSON payloads. If you hand-edit a structured secret like `auth-json`, re-encrypt the whole plaintext file with `sops encrypt --input-type binary --output-type json ...`; encrypting nested JSON fields makes `sops-install-secrets` fail with `error emitting binary store: no binary data found in tree`.

## AI services
- On `britton-desktop`, Docker `--gpus=all` currently fails for OCI containers with `failed to discover GPU vendor from CDI: no known GPU vendor found`. Use CPU images for Infinity/Speaches until the NVIDIA container runtime/CDI setup is fixed.
- The Speaches container writes its Hugging Face cache as the in-container `ubuntu` user. Mount the cache directory with uid/gid `1000:1000` or model preloading fails with `PermissionError` under `/home/ubuntu/.cache/huggingface/hub`.

## Flake evaluation
- `nix flake show --all-systems` fails in this repo unless you pass `--option allow-import-from-derivation true`; the `wasm-plugins` checks evaluate nix-wasm plugin derivations during flake evaluation.

## Packaging
- `pkgs/lemonade/default.nix` must accept either `lemond` or `lemonade-router` as the daemon binary name. Upstream changed names across releases, so install both aliases for compatibility.

## Niri
- The `calling import-environment without specifying desired variables is deprecated` startup message comes from upstream `resources/niri-session` (`systemctl --user import-environment`). In this repo, greetd launches `/etc/profiles/per-user/brittonr/bin/niri-session`, so that warning is session-wrapper noise, not proof that `niri.service` crashed.
- `niri: Page flip commit failed on device ... (Permission denied)` immediately before a boot boundary can be compositor shutdown fallout after DRM master is lost during reboot. Check for surrounding `systemd[1]: Stopping ...` lines before treating it as root cause.

## Wrapped tool wrappers
- Helix wrapper packages from `inputs.wrappers.wrapperModules.helix.apply` keep command bindings in the generated `XDG_CONFIG_HOME` store config referenced by the wrapper script, not inside the final wrapper package root. For integration checks, inspect both the wrapper script (`bin/hx` / `bin/zen`) and the exported config store path.
