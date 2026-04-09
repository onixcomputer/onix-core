# Agent Notes

## Clankers
- `self.packages.<system>.clanker-router` is intentionally patched over the upstream flake package. Use it when you need multiple remote OpenAI-compatible backends; the stock binary only handles one custom `--api-base` endpoint at a time.
- `modules/clankers` router settings accept `localProviders = [{ name, apiBase, models = [ ... ] }]`. The module writes `clanker-router-local-providers.json` and passes it via `--local-provider-config`.
- The daemon must talk to the router proxy through `OLLAMA_HOST`/the module's `apiBase` env wiring, not clankers' `--api-base` flag. `--api-base` only gives clankers the Anthropic-compatible surface, so it never discovers the remote Lemonade models from `/v1/models`.
- If pi shows a Lemonade-backed model selected but no visible reply appears, check the target machine's `journalctl -u lemonade`. A common failure is `request (...) exceeds the available context size`, which means the chat history is longer than the configured `contextSize` even though model lookup succeeded.
