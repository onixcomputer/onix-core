# Tidal and YouTube search

YouTube uses the locked SearXNG `youtube_noapi` engine under Videos and Music. Use `!yt Radiohead`.
It needs no account credentials and does not use Drift's playback process.

Set `enableTidal = true` to add private Tidal catalog search under Music. Use `!tidal Radiohead`.
The adapter returns tracks, albums, and artists, with links to tidal.com. It does not read personal playlists or favorites, change the library, or start playback.
It interleaves result types and returns at most 20 distinct results.

## Authorization

The user authorized reuse of Drift's existing Tidal authorization. The importer reads only the explicit canonical `credentials.json` path.
It rejects symlinks, nonregular files, files owned by another user, public permissions, malformed data, and known expired credentials.
Only the access token enters Clan's encrypted secret store. The importer does not export the refresh token, user ID, or other credential fields.
The runtime YAML renderer reads a root-only environment file. No plaintext account token enters the Nix store or a browser URL.

When Kagi is enabled, Tidal uses the existing Kagi browser-access key. The account tokens remain separate.
A browser that already passed the Kagi access form can search Tidal. Missing and incorrect browser keys remain denied by SearXNG's native query gate.
Without Kagi, Tidal uses its own generated browser-access key through the native preferences token mechanism.
The adapter refuses initialization without a separate browser-access key.

## Access-token lifetime

This is an access-token snapshot, not a second OAuth client.
Drift retains control of its refresh token. SearXNG neither changes Drift's credentials nor refreshes them.
After the imported access token expires or is revoked, Tidal searches fail until the operator imports and deploys a current snapshot.
This implementation does not automatically follow later changes to Drift's credential file.

## Import boundary

The packaged `searx.tidal_credentials` command has three modes:

- `check PATH` validates a private credential file and reports only its status.
- `probe PATH` sends one bounded catalog query and reports only status and result count.
- `export PATH` emits only the access token for a direct secret-import pipe. It refuses terminal output.

Never run export without a private destination. Never paste the output into chat, source files, or command arguments.
The Clan variable is `searxng-searxng-aspen1-tidal/session-token` on Aspen1.
The generator produces the private `env-file` and a separate browser `access-token`.
For a new generator, `clan vars generate ... --no-regenerate` accepts the already imported prompt value and creates missing outputs.
For an existing generator, the operator must regenerate its environment file after a new import, then deploy it and restart SearXNG.
Interactive regeneration can reuse the stored prompt value. Do not use fake prompts or disable the sandbox.

## Network and evidence bounds

Requests use the fixed HTTPS catalog endpoint `https://api.tidal.com/v1/search`, verified TLS, and no redirects.
The parser limits response size to 2 MiB. The standard SearXNG HTTP client still buffers the response before this parser runs.
The operator probe bounds the actual response read. Neither path fetches playback URLs or contacts the OAuth refresh endpoint.

Checks cover valid and invalid records, empty results, query encoding, unsafe identifiers, optional artist metadata, private file rules, terminal-export refusal, response bounds, and native authorization filtering.
The independent review identified missing boundary tests and the HTTP buffering limit. The tests now cover those missing boundaries. The buffering limit remains explicit.

## Reference

[Drift at bb8c23f97c37bb48775d96699a2a1b8dbe26f8be](https://github.com/brittonr/drift/tree/bb8c23f97c37bb48775d96699a2a1b8dbe26f8be) supplies the protocol and credential-schema reference.
The Python adapter is independent. No Rust source was copied.
