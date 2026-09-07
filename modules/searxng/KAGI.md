# Personal Kagi session engine

This engine uses your existing Kagi subscription session. It does not call the official Kagi search API.
Kagi frontend terms apply. This is an unofficial integration for personal, noncommercial use.
The engine does not provide free searches or remove subscription limits.

## Architecture

The pure `kagi_session_core.py` module validates inputs and parses HTML.
The `kagi_session.py` adapter constructs requests and maps errors into SearXNG errors.
The locked SearXNG runtime owns HTTP, TLS verification, timeouts, and private-engine access checks.
No separate Node service, MCP server, token pool, or browser process is necessary.

The adapter uses the fixed `https://kagi.com/html/search` endpoint.
It sends the session token only in the `kagi_session` cookie, never in the query URL.
Redirects remain disabled. HTTP errors and login pages do not count as successful searches.
Rate limits use SearXNG's rate-limit backoff. Server errors do not trigger its long session-rejection suspension.
The parser rejects unrecognized empty pages instead of treating an expired session as zero results.
This also means that a genuine no-results page produces an engine error until a verified empty-page format exists.

Search is limited to the first page of general web results. Images, videos, news, and summaries are not implemented.
The parser returns at most 20 distinct results and rejects HTML larger than 2 MiB.
That size limit bounds parsing, not the framework's HTTP receive buffer.
The engine timeout defaults to 10 seconds and cannot exceed 30 seconds through the Clan interface.

## Private access

The engine has two separate credentials:

- **Kagi session token:** grants access to your Kagi account. Only the server uses it.
- **Engine access token:** grants access to `kagi-private` through SearXNG. Only your client needs it.

Other Tailnet users cannot use the engine without the engine access token.
The engine remains disabled by default in search preferences. After authorization, `!kg query` selects it explicitly.
Ordinary searches continue to use the other engines.

Clan generates a separate private environment file. The runtime YAML renderer consumes it with the existing SearXNG secret file.
Only variable references enter the Nix store. Neither credential belongs in chat, a URL, source control, or a command argument.
No paid API fallback is configured.

## Activation on Aspen1

The inventory now sets `enableKagi = true` for `searxng-aspen1`.
The deployment requires the real session token before activation.

1. Open [Kagi Account settings](https://kagi.com/settings/user_details) in your browser.
2. Copy only the value between `token=` and `&q=` in the Session Link. Do not include `&q=%s`, spaces, or quotes.
   If the link has no next query field, the token ends at the end of the link.
   Never paste the Session Link or token into chat.
3. In the repository, run the hidden Clan prompt:

```console
clan vars generate aspen1 --generator searxng-searxng-aspen1-kagi --option min-free 0 --option max-free 0
```

4. After successful generation, deploy Aspen1:

```console
clan machines update aspen1 --target-host root@aspen1.local --build-host root@aspen1.local --option min-free 0 --option max-free 0
```

5. Retrieve the separate engine access token locally:

```console
clan vars get aspen1 searxng-searxng-aspen1-kagi/access-token
```

6. Open SearXNG Preferences. In the **Kagi access** box, enter that value and click **Unlock Kagi**.
7. Search for `!kg SearXNG` at <https://aspen1.bison-tailor.ts.net/>.

The exact token field label depends on the SearXNG theme.
A client with no engine token, or a wrong engine token, must not make a Kagi request.

### Browser access status

Preferences and HTML search results show a **Kagi access** panel.
The panel distinguishes an unlocked engine, a missing token, a rejected token, and an engine that did not load.
It uses the server's existing access decision. It never prints a credential or removes the private-engine check.
The dedicated **Unlock Kagi** form verifies one issued engine token before it saves the token cookie.
Its button sends an explicit same-origin POST with the engine key and session-bound form token.
The JSON response contains only `saved` or `rejected`. The page then reloads Preferences.
This avoids the native form-submission failure reproduced in Obscura 0.2.0.
It trims surrounding whitespace and preserves other engine tokens and preferences.
A rejected token leaves existing cookies unchanged.
After a successful submission, the panel reports whether the browser returned the saved cookie.
The form includes an unpredictable token bound to a signed browser session.
Its session cookie is Secure, HttpOnly, host-only, and SameSite=Strict.
Missing, incorrect, or cross-session form tokens fail without changing access.
Explicit cross-origin headers also fail. Browsers such as Obscura can omit those headers without bypassing the session-bound check.
Neither the account session token nor the engine access token enters the form-protection cookie.
Before authorization, `kagi-private` appears at the top of Engines → General as **Locked**.
Its **Unlock Kagi** link opens the access form. The locked row has no enable control.
After authorization, the normal engine row appears under Engines → General → web.
The Kagi autocomplete option is separate and does not activate this engine.

## Session rotation and rollback

Signing out of the source Kagi session invalidates its token. Kagi also expires sessions after prolonged inactivity.
Replace the persisted session token locally with `clan vars set aspen1 searxng-searxng-aspen1-kagi/session-token`.
Then run the generation command with `--regenerate` to rebuild its environment file.
Regeneration also rotates the engine access token, so the client token needs an update.
After the secret deployment, restart `searx-init.service` and then `uwsgi.service` to reload the private runtime YAML.

To stop Kagi requests, set `enableKagi = false` and redeploy. Other engines remain available.
To invalidate a leaked session token, sign out of its Kagi session immediately.

## Verification scope

The `searxng-kagi-session` flake check runs synthetic parser fixtures and adapter tests against the packaged SearXNG runtime.
It includes invalid credentials, redirects, login pages, changed markup, unsafe result URLs, size limits, query limits, timeouts, and access-token checks.
It also verifies Unicode decoding, declared charsets, result order, and the real SearXNG engine loader.
The `searxng-module` check verifies secret routing, private-engine configuration, generator errors, and default-off behavior.
Synthetic fixtures do not prove current Kagi HTML compatibility or account authorization.
A real authenticated search remains an activation requirement.

## References

- [kagi-ken, revision 2d29014586a1f7fc012c4073890adc6987711d6f](https://github.com/czottmann/kagi-ken/tree/2d29014586a1f7fc012c4073890adc6987711d6f): protocol and HTML selector reference. No JavaScript source was copied. The native adapter avoids the reference client's implicit redirect handling and missing explicit timeout.
- [SearXNG, revision ef9a188cc8d13acb85923ab9b1eee5a4a484ea64](https://github.com/searxng/searxng/tree/ef9a188cc8d13acb85923ab9b1eee5a4a484ea64): runtime and engine contract, consumed through the existing locked package.
- [Kagi session links](https://help.kagi.com/kagi/privacy/private-browser-sessions.html).
- [Kagi terms](https://kagi.com/privacy#Terms-of-use).
