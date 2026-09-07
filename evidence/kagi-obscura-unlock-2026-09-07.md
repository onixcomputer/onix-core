# Obscura unlock verification

## Reproduced fault

The user requested an Obscura test after the unlock form still failed in their browser.
The anonymous `obscura_fetch` view showed the deployed form.
A credentialed test then used Obscura 0.2.0's CDP server, not Chromium.
The engine access token entered the test through standard input. No credential entered a command argument or test output.

Task 1052 reproduced HTTP 403 from the unlock form. Obscura omitted both Origin and Fetch Metadata headers.
The header-only form guard was replaced with a session-bound form nonce. Explicit cross-origin metadata still rejects requests.
The nonce uses Flask's signed session and a Secure, HttpOnly, host-only, SameSite=Strict cookie.
Missing, incorrect, cross-session, and tampered nonces fail without changing engine access.

Obscura's native form submission still returned 403 after that change.
Its explicit same-origin fetch succeeded, retained the engine cookie across reload, and returned 14 result articles in task 1094.
CDP did not expose request bodies in those events, so the exact native form-serialization fault is not established.

## Repair

`modules/searxng/kagi-unlock.js` now handles the button click and form submission through an explicit POST.
The request contains the engine access token and the session-bound form nonce.
The server returns only a `saved` or `rejected` outcome in JSON.
The client navigates to the fixed preferences page after that response.
The private engine gate remains unchanged.

The script has a bounded request timeout, prevents duplicate submissions, and does not show credential values in errors.
The native HTML form remains as a fallback.
The JavaScript tests cover successful requests, rejected outcomes, network and HTTP errors, malformed outcomes, timeout, duplicate clicks, and pages without the form.
The Python suite covers session binding, signed-cookie flags, cross-origin rejection, token admission, and preserved preferences.

## Deployed evidence

Task 1141 passed the module and packaged Python/JavaScript checks, then deployed the updated service.
Task 1149 used the actual button in Obscura, without direct cookie injection or the earlier fetch-only diagnostic shortcut:

- initial state: missing token;
- unlock request: HTTP 200;
- state after unlock: ready;
- state after an independent page navigation: ready;
- engine cookie remained present;
- explicit Kagi search: 11 result articles.

Task 1156 submitted an incorrect engine key through the same Obscura button.
The result was `rejected`, with no engine cookie and no unlocked engine.

Task 1162 separately verified Chromium's button flow, preservation of other preferences and tokens, wrong-key rejection, and a deliberately discarded-cookie response.
All four service units were active afterward:

- `searx-init.service`
- `uwsgi.service`
- `redis-searx.service`
- `searxng-serve.service`

Active system: `/nix/store/v8r8nzdpq0fk64yjvvnci397lg7xmx72-nixos-system-aspen1-26.11.20260819.afe3d8a`.
The temporary Obscura server was stopped after each test. No private browser profile was inspected.

The user's own final browser submission remains unobserved. These results establish the deployed button flow in Obscura and Chromium, not that the user's browser now works.
No push occurred. Unrelated source changes and the existing repository-wide commit-hook blocker were preserved.
