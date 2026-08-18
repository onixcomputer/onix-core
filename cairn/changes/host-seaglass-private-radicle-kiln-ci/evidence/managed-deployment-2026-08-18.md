# Managed Seaglass and Kiln deployment — 2026-08-18

## Active deployment

| Fact | Value |
|---|---|
| Host | `britton-desktop` |
| System closure | `/nix/store/zkd8hbjpm672p6w7bn81zkjbq2y6vn0j-nixos-system-britton-desktop-26.11.20260803.104240a` |
| Broker | `radicle-ci-broker.service`, active |
| Kiln package | `/nix/store/sq38b7ya66wff7c05k4xqhi87xdf16m1-kiln-0.1.0` |
| Managed Radicle home | `/var/lib/radicle` |
| Seaglass RID | `rad:z3xXXCQXCTquvAawh41YYs8yC8xmk` |
| Seaglass commit | `bea681be760e76a7e18a663df6ed38c2a9d0e1c6` |
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

## Non-claims

The successful replay proves deployed adapter acquisition and one focused
check. It did not pass through a new broker event or update a new Radicle
job COB. A new pushed revision is still required for the final
push-to-status drill.

The configured cgroup covers the broker, adapter, and Nix client. It does
not prove that local Nix daemon workers or remote builders share the same
memory cgroup. Report serving at `ci.onix.computer` also remains open.
