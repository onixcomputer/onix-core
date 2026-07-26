## Context and success contract

Radicle 1.9.1 private visibility carries an identity-document allow set. Protocol peers outside that privacy set must not acquire the repository. Onix currently models one exact public native set and reuses it for HTTPS admission. The pilot must admit a private RID natively without converting private identity policy into an HTTP credential system or exposing the RID through generated HTTPS routes.

Completion evidence is exact repository identity and object convergence on both seeds, independent authorized acquisitions, independent unauthorized failures, HTTPS route absence, encrypted backup, clean-root recovery, and deterministic policy/evidence checks. False completion includes a generic clone that discovers other peers, checking only local storage, relying only on HTTP `404`, using a client already holding the object, or treating a non-secret fixture as proof that production secrets are safe.

## Functional core and imperative shell

The pure settings validators classify canonical RID syntax, uniqueness, exact public/private sets, set disjointness, and HTTPS subset admission. `mk-nixos-config.nix` is the thin lowering shell: it passes the ordered union only to the existing policy reconciler and passes only the public HTTPS set to Nginx generation.

The repository identity document owns peer authorization. Machine modules do not duplicate or mutate the privacy set. Deployment, direct synchronization, isolated client execution, backup, and recovery remain imperative operator actions whose observations are captured in typed evidence.

## Admission model

Public native repositories remain:

- `rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo`;
- `rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f`;
- `rad:z2oYsb9jGTyp68BKYhzpivY1eK58a`.

The private native set contains only `rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg`. The sets must be canonical, unique, exact, and disjoint. HTTPS remains exactly the public set. Explorer pins remain a subset of the public set. CI remains only Bounded Exec.

The private identity delegates to the existing Author DID at threshold one because this is a disposable non-secret mechanism fixture, not accepted production governance. Its explicit allow set contains Aspen, the desktop replica, and authorized client `did:key:z6MkwGV7ypRii8RjoSotmUbuKU4MwGQf3iw8AdhuJkkyD4wd`. Denied client `did:key:z6MksVCc4QAvmZrZXX2MWoGwo9XqDUbiFjsjDZuRZrbgEu6h` remains absent.

## Probe design

Each authorized probe copies only the pre-acquisition client identity into a fresh profile, starts a loopback-only node on a distinct port, connects directly to exactly one seed, clones with that seed NID and minimum signed-reference feature `parent`, computes the Git object and deterministic archive BLAKE3, then stops the node.

Each negative probe uses a fresh denied identity and the same direct-seed topology. It requires the private RID to be absent from remote inventory, the clone command to fail, and no checkout directory to exist. These observations prove only the tested protocol path and version.

HTTPS probes require private upload-pack and receive-pack `404` responses and a healthy public upload-pack response. Seed storage inspection binds identity revision, canonical `main`, delegate namespace `main`, and signed refs.

## Backup and recovery

The existing Aspen Borg job encrypts complete Radicle state to the independent desktop dataset. The pilot triggers a new archive after private convergence. `radicle-backup-restore-verify` restores into a clean bounded root, compares complete manifests and node identity, checks cleanup, and must be followed by a semantic probe of the private repository's exact commit and source hash inside the restored root.

No private key, plaintext repository bundle, or restored tree may leave the source host except encrypted Borg bytes. The non-secret fixture does not relax this handling rule.

## Validation and rollback

Positive and negative node/replica tests cover exact private admission, malformed IDs, duplicates, public/private overlap, and accidental HTTPS widening. Typed receipt negatives mutate visibility, allowed peers, denied behavior, HTTPS status, backup/recovery status, or non-claims and must fail.

Rollback removes the private RID from both private sets, deploys both hosts, reconciles policy, and confirms HTTPS remains closed. Unseeding is not deletion; storage and encrypted archive retirement require a separate authority and retention decision.

## Risks and non-claims

Allowed seeds necessarily learn the RID and store plaintext repository objects. Direct connections reveal traffic metadata. Radicle's tested inventory behavior is not a proof against every discovery mechanism or future version. The pilot does not prove production-secret safety, anonymity, secure deletion, global metadata secrecy, multi-delegate governance, automatic failover, geographic independence, protocol-enforced CI, source correctness, or release eligibility.
