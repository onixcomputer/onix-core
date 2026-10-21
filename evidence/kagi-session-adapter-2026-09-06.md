# Private Kagi session adapter

## Result

The adapter passes offline checks and is deployed on Aspen1.
A live authenticated search returned 14 Kagi results with no engine errors.
Requests with missing and incorrect engine access tokens returned no Kagi results.

## Implementation

- `modules/searxng/kagi_session_core.py`: pure query validation, response classification, and HTML parsing.
- `modules/searxng/kagi_session.py`: native SearXNG engine adapter.
- `modules/searxng/kagi-package.nix`: adds those modules to the existing locked SearXNG package.
- `modules/searxng/default.nix`: opt-in engine, private engine access token, and separate Clan secret generator.
- `modules/searxng/KAGI.md`: personal-use scope, activation, rotation, and rollback.

The engine uses `/html/search` with a session cookie. It has no official API path or paid API fallback.
The fixed endpoint and disabled redirects prevent the session cookie from following a redirect to another host.
The private engine token is separate from the account session token.
The parser rejects unknown empty pages. It does not claim support for genuine zero-result pages without a verified fixture.

## Evidence

The existing module check passed before implementation.
The new package and its first offline suite passed.
An independent read-only review then found three faults: server errors caused session suspension, UTF-8 decoding ignored the HTTP charset, and grouped results lost document order.
New regression tests reproduced all three faults in Nix derivation `/nix/store/viqla29jxv34sh7qzj8ls5qw84hqfww7-searxng-kagi-session.drv`.
After the corrections, the complete suite passed in `/nix/store/xb4wfqhxz05npp7zcacdgjfjwksgnr9f-searxng-kagi-session.drv`.

Final checks passed:

- `checks.x86_64-linux.searxng-kagi-session`: parser cases, real engine loader, request contract, token gate, and framework timeout behavior.
- `checks.x86_64-linux.searxng-module`: default-off behavior, secret references, hidden prompt, private engine tokens, and positive/negative secret generation.
- `checks.x86_64-linux.module-registry-sync`.
- Ruff checks and formatting for the three Python files.
- Scoped Statix checks for `modules/searxng`.
- `git diff --check`.

The real Aspen1 configuration evaluated the Kagi secret generator as:

```json
{"accessTokenDeploy":false,"environmentMode":"0400","environmentSecret":true,"prompt":"hidden","sessionDeploy":false}
```

The user supplied the session token through the hidden Clan prompt and confirmed credential rotation before deployment.
The deployment completed in Pueue task 2096.
The initial deployment activated `/nix/store/86ndjhhb30wk88mlb55dxpaiicv33x9w-nixos-system-aspen1-26.11.20260819.afe3d8a`.
The prior system was `/nix/store/wcgh305d71g8y0rqnjmh59rw9wcvnd41-nixos-system-aspen1-26.11.20260819.afe3d8a`.
The closure diff changed SearXNG and added its Kagi environment secret.

Pueue task 2099 verified:

- `searx-init.service`, `uwsgi.service`, `redis-searx.service`, and `searxng-serve.service` are active.
- HTTPS POST search for `!kg SearXNG` with the valid engine cookie: HTTP 200, 14 Kagi results, no engine errors.
- The same search with no engine cookie value: HTTP 200, no Kagi results, no engine errors.
- The same search with an incorrect engine cookie value: HTTP 200, no Kagi results, no engine errors.

The probe loaded credentials only on Aspen1. It passed the engine cookie through curl standard input, not command arguments.
Only HTTP status, result counts, and engine errors entered the tool output.
Private response files under `/run` were removed after the probe.

## Browser visibility follow-up

The user reported that `kagi-private` remained absent after they saved the engine token.
The server token comparison passed. A minimal HTTP form save also passed.
A fresh Chromium profile then submitted the full preferences form, retained the correct cookie, displayed the engine control, and returned 14 live results.
An incorrect cookie hid the engine as expected. The user browser's fault is not reproduced.

The investigation used three approaches: token drift, full-form save behavior, and browser cookie/visibility behavior.
The first two passed. The user's actual browser state remains unknown.
A separate read-only review worker reached its time limit without a report. It supplied no independent evidence.
The first browser run used an incorrect tab selector. The corrected selector passed before product changes.

Preferences and HTML results now show a Kagi access panel with four states: `ready`, `missing`, `rejected`, and `unavailable`.
The renderer passes only availability, token presence, and the existing authorization decision to this panel.
The private-engine check remains unchanged. The panel never prints credentials.

The first panel patch introduced a Python indentation error through a multiline Nix substitution.
Deployment task 2197 was stopped before activation. The prior system and active uWSGI service were verified afterward.
A new packaged-webapp compilation test reproduced that error in task 2204.
A dedicated patch file replaced the multiline substitution. Packaging now compiles the patched webapp before building the wheel.

After correction, Ruff, scoped Statix, module checks, and the complete offline suite passed in task 2209.
The successful test derivation is `/nix/store/826w11mf146ynsag2nipz4q697wbpx7a-searxng-kagi-session.drv`.
Deployment task 2216 activated `/nix/store/pl6sn0wiyaicjcpdf3287r4q80z5yks5-nixos-system-aspen1-26.11.20260819.afe3d8a`.
Browser task 2220 verified the deployed panel:

- Fresh browser: `missing`, no private engine control.
- Full form save: cookie and field match, status `ready`, private engine control visible.
- Live `!kg SearXNG` search: 14 result articles.
- Incorrect cookie: status `rejected`, no private engine control.
- All four service units remain active.

The remaining diagnostic is the panel state in the user's browser. This work does not claim to fix that browser's unknown fault.

## Boundaries

The offline tests use synthetic HTML and fake tokens. The live probe separately verifies current authenticated search behavior and result access controls.
The probe does not independently count upstream requests for denied clients or establish permission under Kagi's subscription terms.
The source remains uncommitted because the existing repository-wide commit hooks fail on unrelated files. No push occurred.
SearXNG remains available at `https://aspen1.bison-tailor.ts.net/` through private Tailscale Serve.
