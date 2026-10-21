# Tidal authorization reuse and media deployment

## Scope and authorization

The user requested YouTube and Tidal engines, then explicitly authorized reuse of Drift's Tidal authorization.
Only Drift's current access token was imported into Clan's encrypted secrets. No refresh token was copied or used.
The import did not modify Drift's credential file, playback process, library, or queue.
Tidal queries use the native private-engine gate and the existing Kagi browser-access key on Aspen1.
The account token never enters a browser cookie or URL. The browser key is a separate credential.

This is a snapshot. Future Drift token changes do not propagate automatically. An expired or revoked token requires another import and deployment.

## Implementation and checks

The adapter uses the Tidal catalog search endpoint documented by Drift at bb8c23f97c37bb48775d96699a2a1b8dbe26f8be.
Pure rules validate queries, tokens, identifiers, response shape, optional artist metadata, result bounds, and URL construction.
The shell supplies headers and HTTP behavior. It never contacts the refresh endpoint or playback endpoints.
The importer rejects public permissions, wrong ownership, symlinks, nonregular files, malformed data, known expiry, and terminal export.

The baseline checks passed. The updated module, Tidal, Kagi, and developer-engine Nix checks passed.
Ruff and scoped Statix passed. The Tidal suite includes nine positive/negative test methods.
An independent read-only review identified missing boundary tests and the HTTP receive-buffer limitation.
The additional tests cover those missing boundaries, including native query filtering for shared and dedicated browser keys.
The production parser caps JSON input after SearXNG buffers the response. The operator probe also bounds the network read.

A direct probe with Drift's authorization returned 20 results before import.
No credential value was printed in tool output or supplied in command arguments.

## Safe deployment

The initial primary-checkout candidate removed existing Campaign Git routes. That candidate was not activated.
The deployment worktree is /home/brittonr/git/onix-core-searx-media on branch searxng-tidal-deploy, based on published commit 59d1cdbd.
That baseline contains the already approved forge policy. No ad-hoc route exception was added.
Unrelated staged work in the primary checkout remains untouched.

Previous system: /nix/store/2z8a8cdrdaa9vdcha554inq517rrbkx3-nixos-system-aspen1-26.11.20260819.afe3d8a.
Initial verified system: /nix/store/ila2v4nlck43r6bay0c5hbhqrs4k6gqf-nixos-system-aspen1-26.11.20260819.afe3d8a.
Final committed system: /nix/store/b2p64s205ca4gn451cy1sjw9sr7g9y7h-nixos-system-aspen1-26.11.20260819.afe3d8a.
The final build includes the hook-formatted assets from b00d9718. All four focused Nix checks and the full pre-commit Nix check passed.

The preview showed only the SearXNG package change and the new encrypted Tidal secret source. No existing package was removed.
The old and new Nginx units matched byte for byte. The activation command rejected a changed live-system baseline and included rollback on switch failure.
Activation succeeded. uWSGI, Redis, Tailscale Serve, and Nginx were active afterward.

## Live browser evidence

A fresh Chromium context submitted the existing Kagi unlock form. The browser received only the private-engine access key.

| Search | Result articles |
| --- | --- |
| Tidal | 20 |
| YouTube | 18 |
| NixOS options | 2 |
| Home Manager options | 1 |
| Noogle | 3 |
| GitHub | 30 |
| Kagi | 11 |

The Tidal results included tracks, albums, and artists. Every result carried the Tidal engine label and a tidal.com link.
Missing and incorrect browser keys returned no Tidal links.
These are fresh-browser checks, not a claim about the user's existing browser state.

Forge discovery returned HTTP 200 for both the bare and publisher-namespace routes. Write discovery remained denied with HTTP 404.
The Kagi canary completed with Result=success and ExecMainStatus=0.

## Commit handling

Clan's native secret commands initially created two local automatic commits. Inspection then revealed that Clan uses --no-verify internally.
The two unpublished automatic commits were replaced with b00d9718, a normal commit that passed deadnix, Statix, and treefmt hooks.
The replacement preserved the encrypted files and all implementation changes.
Further Clan mutations must use CLAN_NO_COMMIT=1, followed by a normal checked commit.
No push is authorized or performed for this task.

## Evidence files

- /tmp/searx-media-final-preview.log
- /tmp/searx-media-activation.log
- /tmp/searx-media-browser.log
- /tmp/searx-tidal-review.log
- /tmp/searx-media-final-build.log
- /tmp/searx-media-committed-build.log
- /tmp/searx-media-committed-activation.log
- /tmp/searx-media-committed-browser.log
- /tmp/searx-media-commit.log

Future Aspen1 deployments must preserve the published forge policy. The old primary-checkout baseline still lacks that policy.
