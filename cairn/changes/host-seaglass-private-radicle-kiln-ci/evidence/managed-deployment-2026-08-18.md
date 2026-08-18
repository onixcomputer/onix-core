# Managed Seaglass and Kiln deployment — 2026-08-18

## Active deployment

| Fact | Value |
|---|---|
| Host | `britton-desktop` |
| System closure | `/nix/store/3aby9cqw9kvycic9z16kl55hy1xckrb6-nixos-system-britton-desktop-26.11.20260803.104240a` |
| Broker | `radicle-ci-broker.service`, active |
| Kiln package | `/nix/store/sq38b7ya66wff7c05k4xqhi87xdf16m1-kiln-0.1.0` |
| Managed Radicle home | `/var/lib/radicle` |
| Seaglass RID | `rad:z3xXXCQXCTquvAawh41YYs8yC8xmk` |
| Seaglass commit | `44ed329b09e472aa12866c8dceedbfb3526b25a1` |
| Seaglass identity | `34622578746c320714509e309233fc7df051d202` |
| Managed node identity | `did:key:z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG` |

Clan deployed through `root@britton-desktop.clan` with strict host-key
checking. The deployed broker has a 24 GiB memory limit, an eight-core CPU
quota, one concurrent adapter, a two-hour adapter timeout, and an eight
MiB capture bound for each output stream.

## Private replication

The Seaglass identity remains private. Its `visibility.allow` list contains
only the reviewed managed node identity. The authoring identity remains
the only delegate and the threshold remains one.

Private repositories do not enter public inventory announcements. The
`radicle-seaglass-replicate.service` therefore performed an explicit
native fetch from the supervised personal node. It discovered that node's
operating-system-selected loopback address through its control socket.

The service completed with these aggregate observations:

```text
Target met: 1 preferred seed
replicated the reviewed Seaglass revision into managed Radicle storage
```

The service then proved that managed storage contains the reviewed commit
and exact identity revision. Its final state is `active (exited)`, result
`success`, and exit status zero.

## Broker observation

The first managed fetch produced a `BranchCreated` event. The broker
accepted all three trigger filters:

- repository equals the private Seaglass RID;
- the exact commit contains `flake.nix`; and
- `master` is the default branch.

The broker created run `9b04e10f-4b20-4378-9ae2-04b1ef10b88c` and Kiln
run `kiln-bea681be-1787063718185249631`. This first run failed because the
adapter environment did not contain Git. The retained report showed:

```text
error: executing "git": No such file or directory
```

Onix-core then added the reviewed Git package only to the Kiln adapter
`PATH`. The generated broker configuration passed `cib config` after this
change.

A focused replay ran the deployed adapter as the `radicle` service user
against the same managed RID and revision. It used the existing
`component-purity` check and completed successfully:

```text
{"response":"triggered","run_id":{"id":"kiln-bea681be-1787064053061270518"},"info_url":"https://ci.onix.computer/reports/z3xXXCQXCTquvAawh41YYs8yC8xmk/kiln-bea681be-1787064053061270518.log"}
{"response":"finished","result":"success"}
```

## Full push-to-status drill

The first full push exposed Cairn's transitive private Artifact input.
Flake evaluation and Cargo vendoring both tried the locked GitHub SSH URL.
The executor did not receive an account SSH key. Instead, onix-core
injected its immutable Artifact input, and Seaglass routed only the exact
reviewed URL and revision to that input during Cairn vendoring.

The source-routing check has positive and negative cases. It verifies the
Git revision from Cairn's unchanged lock and the content through the Nix
archive hash. The full adapter preflight then passed before `master`
moved.

The authoring node pushed `master` from `d897df935…` to
`44ed329b09e472aa12866c8dceedbfb3526b25a1`. The managed node fetched that
exact object. The broker admitted the repository, `flake.nix`, and default
branch filters. It then created these identities:

| Identity | Value |
|---|---|
| Broker run | `160ad4be-1302-450f-91b4-98f25262f72c` |
| Kiln run | `kiln-44ed329b-1787068902888322241` |
| Radicle job | `01b27c46a30de07fa2679e9f867926466c53eeab` |

The bounded report records the exact revision and terminal success:

```json
{
  "branch": "master",
  "repository": "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk",
  "result": "success",
  "revision": "44ed329b09e472aa12866c8dceedbfb3526b25a1",
  "run_id": "kiln-44ed329b-1787068902888322241",
  "schema": "onix.radicle-ci-report.v1"
}
```

`cibtool run list --json` independently reports the broker run as
`finished`, with result `success`, the same commit, Kiln run, and Radicle
job identity.

## Private report serving

Onix-core commits `04b13d7f` and `a0642926` added and deployed private
report serving. The final system closure is:

```text
/nix/store/ahrk9xgv59lkms91rm831z612fhm2d5c-nixos-system-britton-desktop-26.11.20260803.104240a
```

The `radicle-ci-reports` service runs as `radicle` and reads the retained
report directory through a read-only systemd boundary. It binds only
`127.0.0.1:8990`. The backend port is absent from the global firewall
list. The unit has a `256M` memory limit and a `100%` CPU quota.

Traefik accepts only `ci.onix.computer` paths equal to `/reports` or below
`/reports/`. It applies the `100.64.0.0/10` tailnet source allowlist before
it strips the prefix. The route then applies the shared security headers.
The DNS A record points to the managed tailnet address `100.110.43.11`.

The original desktop Cloudflare token was stale. Cloudflare returned error
`9109`, `Invalid access token`. The deployment reused an existing valid,
owner-managed token from onix-core and re-encrypted it for the desktop
recipients. The DNS script now fails if Cloudflare rejects the zone
lookup, record lookup, or record creation. It no longer reports a false
successful service start after a rejected update.

A strict TLS request to this exact URL returned the retained success
report without `--insecure` or a local hostname override:

```text
https://ci.onix.computer/reports/z3xXXCQXCTquvAawh41YYs8yC8xmk/kiln-44ed329b-1787068902888322241.json
```

The observed route results were:

| Probe | Result |
|---|---|
| Report index | HTTP `200` |
| Exact JSON report | HTTP `200` with revision `44ed329b09e472aa12866c8dceedbfb3526b25a1` |
| Missing report | HTTP `404` |
| Host path outside `/reports` | HTTP `404` |

The node, broker, report server, Traefik, and private DNS service were all
active after deployment.

## Non-claims

The passing full flake run proves the relation between the pushed commit
and the current Seaglass flake surface. GitHub-only parity rails remain
open until they become flake checks.

The configured cgroup covers the broker, adapter, and Nix client. It does
not prove that local Nix daemon workers or remote builders share the same
memory cgroup.

The reused Cloudflare token also has Cloudflare Tunnel edit authority. A
new token limited to zone read and DNS edit would reduce desktop authority.
The static policy check verifies the tailnet allowlist. The live
public-address hairpin probe could not connect, so it did not independently
exercise Traefik's HTTP `403` path from a non-tailnet source.
