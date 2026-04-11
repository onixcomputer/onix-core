# Agent Notes

## Clankers
- `self.packages.<system>.clanker-router` is intentionally patched over the upstream flake package. Use it when you need multiple remote OpenAI-compatible backends; the stock binary only handles one custom `--api-base` endpoint at a time.
- `modules/clankers` router settings accept `localProviders = [{ name, apiBase, models = [ ... ] }]`. The module writes `clanker-router-local-providers.json` and passes it via `--local-provider-config`.
- The daemon must talk to the router proxy through `OLLAMA_HOST`/the module's `apiBase` env wiring, not clankers' `--api-base` flag. `--api-base` only gives clankers the Anthropic-compatible surface, so it never discovers the remote Lemonade models from `/v1/models`.
- If pi shows a Lemonade-backed model selected but no visible reply appears, check the target machine's `journalctl -u lemonade`. A common failure is `request (...) exceeds the available context size`, which means the chat history is longer than the configured `contextSize` even though model lookup succeeded.
- For `clan ... --build-host <machine>`, the deploy copy runs on the build host (`nix copy --to ssh-ng://root@<target>`). The build host's root account needs its own working SSH identity for the target; forwarded agents can fail with `agent refused operation` on the second hop.

## Clan deploys
- On this workstation, `clan machines update ...` can lose vars generator `finalScript` store paths to local auto-GC mid-run (`/nix/store/...-generator-...: No such file or directory`). If that happens, rerun the deploy with `NIX_CONFIG=$'min-free = 0\nmax-free = 0'` so the generator script survives long enough to execute.
