# Design: execution-graph Radicle source admission

## Policy model

One ordered public-source list contains Bounded Exec, `artifact-auth`, and `execution-graph`. Primary seeding, HTTPS routes, and replica seeding derive from that list. Bounded Exec keeps its separate CI policy.

The deployed hosts also carry a separately managed private RID. Public-source admission must preserve that live policy without recording private repository facts in public evidence.

## Validation

The pure validators require exact ordered membership, canonical RID syntax, unique entries, the `parent` signed-reference feature, and unchanged host identities. Negative tests cover every missing source, unknown additions, duplicates, malformed RIDs, HTTPS mismatch, and replica mismatch.

## Deployment shell

Nix modules own the durable public policy. A runtime systemd drop-in can stage the new public RID without rebuilding unrelated host state. The drop-in must preserve every existing live RID and must be replaced by normal deployment before reboot.

Seeds receive only signed public storage. HTTPS exposes exact info-refs and upload-pack routes. Neither path receives repository signing authority.

## Failure and rollback

If replication or HTTPS verification fails, remove the runtime drop-ins, reload systemd, and restore the prior Nginx service configuration. Do not delete repository storage.

Consumer rollback remains separate. GitHub stays a transition mirror until consumer evidence is accepted.

## Evidence

Evidence must bind the RID, reviewed commit, source BLAKE3, seed identities, runtime policy, HTTPS route, negative probes, temporary-drop-in status, and governance blocker. No receipt may claim canonical publication before the producer records the accepted delegate threshold.
