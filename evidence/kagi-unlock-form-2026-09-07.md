# Dedicated Kagi unlock form

## Result

The user browser reported that no engine token reached the preferences page.
A dedicated **Unlock Kagi** form is now deployed. The private-engine check remains enabled.
The user's final browser outcome still requires their own form submission.

## Behavior

- The form sends the separate engine access token by HTTPS POST to `/kagi-access`.
- The server accepts only an issued engine token. It trims surrounding whitespace.
- The server preserves other engine tokens and unrelated preferences.
- Rejected submissions do not replace existing cookies.
- A successful submission redirects to Preferences. The panel reports a missing cookie after that redirect.
- No Kagi session credential enters the form, URL, response body, or probe output.

The pure `admit_access_token` function owns the token-set update.
`modules/searxng/kagi_unlock.py` owns the Flask form adapter and native token-cookie save.
The installed SearXNG engine gate still controls searches.

SearXNG sends `Referrer-Policy: no-referrer`. A real Chromium form probe observed `Origin: null` with `Sec-Fetch-Site: same-origin`.
The adapter admits this browser case only with same-origin Fetch Metadata.
Cross-site, same-site-only, absent-origin, contradictory-origin, and GET controls reject access.

## Verification

The original module and package checks passed before changes.
The updated package check passed at `/nix/store/kyj93c04dgnqk4ygpcb5v2iaxdsb1lgl-searxng-kagi-session.drv`.
Tests cover valid admission, whitespace, malformed input, missing engines, locked preferences, cookie preservation, request origin, and all panel states.
Ruff, scoped Statix, and `git diff --check` passed.

One initial test inspected the raw comma-escaped cookie string instead of its decoded value.
The corrected test performs an actual cookie round trip through Flask before checking preserved token values.

Deployment initially failed because Aspen1 could not download the pinned Octet source from GitHub.
The exact cached input was copied to Aspen1 through `nix copy`. No flake input or lockfile changed for this repair.
Task 911 then deployed the verified module.

Task 912 verified the real browser form, surrounding-whitespace acceptance, preservation of another engine token and a language preference, and 20 live result articles.
The initial cookie-loss browser fixture did not intercept a redirected request. Its assertion failed because the cookie remained present.
The corrected fixture discards the POST response's cookie before the redirect.
Task 922 passed the complete form test, wrong-token rejection, and explicit discarded-cookie diagnostic.
Credentials stayed in process memory and browser cookies. Probe output contained only status values and counts.

Task 926 verified the active system and all four service units:

- `/nix/store/7kx2mi6h1famaami1wbiplyd126z0qy7-nixos-system-aspen1-26.11.20260819.afe3d8a`
- `searx-init.service`: active
- `uwsgi.service`: active
- `redis-searx.service`: active
- `searxng-serve.service`: active

No push occurred. The existing repository-wide commit-hook blocker remains outside this change.
