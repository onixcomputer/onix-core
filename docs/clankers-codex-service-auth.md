# Clankers Codex service auth

## Export a provider record

From a workstation with a working local login:

```bash
clankers auth export openai-codex --account default > codex-default-record.json
# or
clanker-router auth export openai-codex --account default > codex-default-record.json
```

The exported JSON contains the provider name, account name, active flag, and
credential payload needed to restore that one account on another machine.

## Seed the record into clan vars

The router generator now prompts for provider/account-scoped record JSON.
For `aspen2`, the relevant prompt names are:

- `anthropic-claude1-record`
- `anthropic-claude2-record`
- `anthropic-claude3-record`
- `openai-codex-default-record`

Paste the compact exported JSON for each prompt, then regenerate the shared
router auth secret:

```bash
clan vars generate aspen2 --generator clanker-router-clankers --regenerate
```

The generated secret remains a raw SOPS binary blob at:

- `vars/shared/clanker-router-clankers/auth-json/secret`

Check it decrypts to plain JSON, not nested SOPS field encryption:

```bash
sops -d vars/shared/clanker-router-clankers/auth-json/secret | jq '.providers'
```

## Runtime refresh layout

The deployed router now uses two auth locations:

- seed: `/run/secrets/vars/clanker-router-clankers/auth-json`
- runtime: `/var/lib/clanker-router/auth-runtime.json`

The seed file is read-only deployment input.
Refreshes and account-switch mutations write only to the runtime file.

## Redeploy and replacement recovery

After runtime refreshes, back up the refreshed account record from the machine
before replacement or rebuild:

```bash
clanker-router --auth-runtime-file /var/lib/clanker-router/auth-runtime.json \
  auth export openai-codex --account default > codex-default-record.json
```

Re-import that record into clan vars, regenerate `auth-json`, and redeploy.
This preserves the freshest service credential without mutating the repo-managed
seed file in place.

## Sanity checks

On the target machine:

```bash
clanker-router \
  --auth-seed-file /run/secrets/vars/clanker-router-clankers/auth-json \
  --auth-runtime-file /var/lib/clanker-router/auth-runtime.json \
  auth status --provider openai-codex

clanker-router \
  --auth-seed-file /run/secrets/vars/clanker-router-clankers/auth-json \
  --auth-runtime-file /var/lib/clanker-router/auth-runtime.json \
  models --provider openai-codex
```

If `~/.codex/auth.json` is source material, probe it first. `codex login status`
can still say logged in while the stored refresh token already fails with
`refresh_token_reused`.
