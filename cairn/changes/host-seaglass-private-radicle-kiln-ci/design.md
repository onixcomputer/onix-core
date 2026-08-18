# Design: Seaglass private Radicle and Kiln CI on britton-desktop

## Host decision

The operator selected `britton-desktop` as the CI host. This machine
runs the personal Radicle node as user `brittonr`, is the reviewed backup
target for the production Radicle seed, and never suspends. It is inside
the accepted private-visibility seed set used by the existing private
pilot.

The alternative host, `tower`, is not managed by `onix-core`. Choosing
`britton-desktop` keeps the migration inside the reviewed `onix-core`
deployment boundary.

## Acquisition path

The broker adapter builds the exact pushed revision directly from the
Radicle storage the broker service uses. The adapter resolves
`git+file://$RAD_HOME/storage/$rid?rev=$oid`. No consumer flake input is
involved.

The deployment seeds the private Seaglass RID with scope `all` into
that `britton-desktop` Radicle storage. Private repositories do not enter
normal public inventory announcements, so policy reconciliation alone
cannot bootstrap the first copy.

A bounded one-shot service queries the supervised personal node through
its existing control socket. It reads that node's operating-system-selected
loopback address, confirms that the repository identity authorizes only
the reviewed managed node, connects the managed node to the source, and
runs native `rad seed --from`. The service then verifies the reviewed
Seaglass identity and commit
inside managed storage. Its root authority is limited to read-only access
to the personal Radicle home and the existing managed-node control path.
It cannot bind a network listener.

After this first native replication, acquisition never needs GitHub or a
public Radicle seed. A private seed HTTP Git endpoint is intentionally out
of scope. It is useful only when a machine or flake consumes Seaglass as
an input, which this change does not do.

## Control plane and execution split

Kiln owns the broker protocol mapping and the deployed CI run contract.
The published `kiln-adapter-radicle` binary is the visible composition
root for one accepted broker request. It maps the request, acquires the
exact local revision, invokes Nix, binds the observed process result,
writes a bounded report, and returns one triggered line and one terminal
line.

The Radicle CI broker owns repository filtering, event persistence,
adapter dispatch, adapter timeout, and Radicle job status publication.
There is no second Nix adapter process. Nix execution is an imperative
shell capability inside the Kiln Radicle adapter.

The published executor is an operational bridge. Run identity creation
and terminal classification still occur in the adapter shell. Kiln tracks
the provider-port and pure-decision cleanup in its active
`align-provider-port-ownership` change. This onix-core change does not
claim that cleanup is complete.

## Why the broker and Kiln adapter, not the pilot runner

The existing `radicle-ci-runner` module serves one fixed reviewed
commit with immutable lock identities and one bounded command. Seaglass
is a living repository with many rails and a large flake. The broker and
Kiln adapter path handles arbitrary pushed revisions and builds the whole
admitted check set. It is the reference integration named in the Kiln
hosting and integration contracts.

## Resource boundaries

The broker admits one adapter at a time and terminates an adapter after
two hours. The adapter retains at most eight MiB from each process output
stream. The systemd broker cgroup has an eight-core CPU quota and a 24 GiB
memory limit.

The cgroup covers the broker, adapter, and Nix client. It does not prove
that local Nix daemon workers or remote builders share the same memory
cgroup. Full executor memory isolation remains open until the build
execution boundary supplies enforceable per-run limits.

## Seaglass flake parity

GitHub Actions currently runs rails that are not flake checks. The
private CI path builds only the flake `checks.<system>` set. Every rail
that must survive cutover becomes a named check. Any rail left
GitHub-only appears in a named gap report.

## Evidence

Each phase emits evidence under this change package: seed acquisition
probes, Radicle bookmark observations, adapter fixtures, executor bound
records, the checked revision report, the seed-set observation, and the
final parity gap report. The change archives only after every gate
passes.
