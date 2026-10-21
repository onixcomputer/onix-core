# pi model access transferred to omp

Date: 2026-09-15

Hosts: `britton-desktop`, `aspen3`. Both run omp 18.1.19 and pi with
per-user state under `~/.pi/agent`.

No secret value entered this repository, the Nix store, or any log.

## Credentials

`openai-codex` OAuth accounts moved through omp's own importer. pi's
`~/.pi/agent/auth.json` entries were rewritten into the CLIProxyAPI shape
the importer accepts (`access_token`, `refresh_token`, `expired`,
`account_id`) and imported with `omp auth-broker import`, which resolves to
the local SQLite store when no auth broker is configured.

| host | OAuth credentials | API keys |
| --- | --- | --- |
| `britton-desktop` | 4 × `openai-codex` | `openrouter`, `zai`, `opencode-go` |
| `aspen3` | 4 × `openai-codex` | `openrouter`, `zai`, `opencode-go`, `opencode` |

API keys are rows in `~/.omp/agent/agent.db` (`auth_credentials`) with
`credential_type = 'api_key'` and `data = {"key": …}`, matching the
serializer omp uses for its own logins.

## Models

pi's custom providers moved into omp's user models config
(`~/.omp/agent/models.yml`):

- `lemonade-aspen1`, `lemonade-aspen2`, `local-dspark`, `mesh`, `ollama`,
  and on `britton-desktop` also `opencode-free`;
- `openai-codex` (and its account variants) and `opencode-go` were skipped
  because omp's bundled catalog already defines those providers and models.

Fields omp's schema does not accept were dropped: `compat.chatTemplateKwargs`,
`compat.sessionAffinityFormat`, `compat.thinkingFormat` values outside omp's
enum (`chat-template`, `deepseek`), model `thinkingLevelMap`, and provider
`modelOverrides`. pi's `local-dspark` entry names
`deepseek-v4-flash-0731-ablit-100`, which that endpoint no longer serves, so
the live `deepseek-v4.1-flash` was added alongside it.

Defaults follow pi: `enabledModels` (account providers collapsed onto one
provider), `defaultThinkingLevel = low`, and `modelRoles.default` —
`local-dspark/deepseek-v4.1-flash` on the desktop,
`openai-codex/gpt-6-astra` on aspen3.

## Verification

Live non-interactive requests, one per credential family:

| host | probe | result |
| --- | --- | --- |
| desktop | `openrouter/~deepseek/deepseek-flash-latest` | `openrouter-ok` |
| desktop | `local-dspark/deepseek-v4.1-flash` | `dspark-ok` |
| desktop | `zai/glm-4.5-air` | authenticated; account weekly/monthly limit reached |
| desktop | `openai-codex/gpt-5.4-mini`, `openai-codex/gpt-6-astra` | authenticated; model-unsupported and usage-limit responses |
| aspen3 | `local-dspark/deepseek-v4.1-flash` | `dspark-ok` |
| aspen3 | `openrouter/~deepseek/deepseek-flash-latest` | authenticated; 402 credits exhausted |

`~/.omp/agent/{agent.db,config.yml,models.yml}` are mode 0600 on both
hosts. Temporary import directories were removed on both hosts.

## Default model

Both hosts default to the dspark-hosted DeepSeek V4.1 Flash at the top
thinking level:

```yaml
enabledModels: [openai-codex/gpt-6-astra, zai/glm-5.3, zai/glm-5.3-flash, local-dspark/deepseek-v4.1-flash]
defaultThinkingLevel: max
modelRoles:
  default: local-dspark/deepseek-v4.1-flash
```

pi carried that endpoint's thinking over `chatTemplateKwargs` with
`thinkingFormat: chat-template`, which omp's schema rejects. omp's equivalent
for the vLLM path is `qwen-chat-template`, which rides the same
`chat_template_kwargs` channel, so the transferred `deepseek-v4.1-flash` entry
carries `compat.thinkingFormat: qwen-chat-template`. The endpoint honoured the
kwargs: the same prompt that used 14 prompt tokens without them used 40 with
`{thinking: true, reasoning_effort: max}`.

Verified by running the default model on both hosts:

```text
provider=local-dspark model=deepseek-v4.1-flash
content=[thinking "Simple. 17*23 = 391.", text "391"]
```

`defaultThinkingLevel` and `modelRoles.default` are identical in
`~/.omp/agent/config.yml` on `britton-desktop` and `aspen3`.

## Limits

The quota, credit, and model-availability responses prove the credentials
authenticate; they are account state, not transfer failures, and the same
limits apply to pi on those accounts. `mesh` models returned HTTP 400
"streaming responses are not supported" under omp, and the lemonade
endpoint on aspen1 did not answer during the check. This evidence does not
prove model quality, availability, or that omp keeps using these
credentials after they expire — omp refreshes OAuth tokens from the stored
refresh tokens.
