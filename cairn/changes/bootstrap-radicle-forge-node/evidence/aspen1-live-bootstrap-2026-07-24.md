# Aspen1 live bootstrap observation — 2026-07-24

## Scope

This bounded observation records the first activation and clean recovery of the reviewed Radicle service on Aspen1. It is deployment and recovery evidence, not the final deterministic bootstrap receipt.

## Preserved state and identity

- Pre-activation discovery found `/var/lib/radicle` already contained 56 GiB and 6,760 top-level storage directories from an earlier Clan-managed Radicle deployment.
- The persisted node fingerprint was `SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE`.
- Repository history retained the matching Aspen1 Clan-encrypted private key and non-secret public key from commit `b72e3a90`.
- The historical private key was decrypted only into a mode-`0600` temporary file, fingerprint-checked without printing key material, removed on command exit, and re-encrypted into the current service-specific, machine-scoped Clan variable.
- The current private and public halves both produced the persisted fingerprint before deployment.
- The node resumed as `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`.

A newly generated identity was not activated because it would have changed the node ID and stranded the inherited state. The module now lowers an accepted canonical RID allowlist into exact Git upload-pack routes with a default 404, but public HTTPS remains disabled until a real pilot RID and stable DNS/TLS name are admitted.

## Activated closure

- NixOS closure: `/nix/store/9a64xdgdampmy044f1l347bmmjs0gwhp-nixos-system-aspen1-26.11.20260629.7a1a647`
- Radicle node: `/nix/store/r2hjw60rdpb3faxa6xglywxl77rx9ql2-radicle-node-1.9.1`
- Radicle HTTP daemon: `/nix/store/zjnwy6nnilq6f4jnsm1h4wjiapwi36va-radicle-httpd-0.25.0`
- Deployment path: `root@aspen1.local`; this mDNS name is not a client endpoint.

## Positive observations

- `radicle-node.service` and `radicle-httpd.service` were active and enabled after activation.
- The native peer listener was exactly `100.100.103.95:8776`.
- The HTTP listener was exactly `127.0.0.1:8080`; no Radicle listener was present on port 443 or a wildcard address.
- nftables admitted TCP port 8776 on `tailscale0`; port 8080 was not globally admitted.
- Local `GET /api/v1/node` returned node state `running`, agent `/radicle:1.9.1/`, the preserved node ID, and `seedingPolicy.default = "block"`.
- A client request to `100.100.103.95:8080` failed to connect, confirming that the HTTP daemon was not reachable through the tailnet address.
- A controlled restart returned both units to `active` and preserved the same node ID, fingerprint, package version, external address, and default-block seeding policy.
- The node process environment contained no variable names matching delegate, GitHub, Buildbot, Cloudflare, Vault, Matrix, cache, release, deployment, signing, token, or secret authority.
- The `radicle` account could read zero of the host secret files observed under `/run/secrets`; systemd loaded only the dedicated node identity and retained the optional passphrase credential boundary.
- Prometheus, node-exporter, and systemd-exporter were active. The systemd exporter reported `systemd_unit_state{name="radicle-node.service",state="active",type="service"} 1`, and the Prometheus query returned that series for Aspen1.
- Prometheus loaded `RadicleNodeNotActive`, `RadicleHttpdNotActive`, and `RadiclePolicyReconcileFailed`. The reconciliation failure series was present with value zero.
- `radicle-policy-reconcile.service` completed successfully with zero additions and removals, its timer was active, its network namespace admitted only `AF_UNIX`, `/run/secrets` was inaccessible, and the unit had no credential directives.
- A bounded negative probe added the public Heartwood RID as an undeclared native seed policy, started reconciliation, and observed the policy removed. Cleanup and a second reconciliation left `rad seed` reporting no policies.

## Off-host encrypted backup and clean recovery

- `britton-desktop`, declared as the separate `britton-desktop-workstation` failure domain, now hosts only the dedicated Borg repository at `/var/lib/radicle-backup/aspen1` on ZFS dataset `datapool/radicle-backup`.
- The dataset and Borg server quota are 256 GiB. The live dataset used 48.9 GiB with 207 GiB available after the accepted archive. `/var/lib/radicle-backup` was `0710 root:borg`; the repository was `0700 borg:borg`.
- The destination Borg repository ID is `8d87c9acca56a9dfac56f152c98bd5dec748260ca5d7ba4bfe9fba95c1916921`. `borg info` reported `Encrypted: Yes (repokey)`. Aspen1 uses a repository-specific SSH key, a pinned Ed25519 host key, strict host-key checking, `--restrict-to-repository`, no subrepositories, and seven daily plus four weekly archives.
- The desktop has no Radicle node service, no readable Borg-user host secrets, and no delegate, deployment, release, signing, cache-write, canonical-ref, or CI authority. Its accepted closure was `/nix/store/xvdn34kpi18jw4gpyi5rkaihhzy5p6hj-nixos-system-britton-desktop-26.11.20260629.7a1a647`.
- Aspen1's backup job receives exactly the Radicle private key, Borg SSH key, and Borg repokey passphrase through its private systemd credential directory. It masks `/run/secrets` and all of `/var/lib`, exposes only `/var/lib/radicle` through a read-only bind alias, and retains only `CAP_DAC_READ_SEARCH`. `ProtectHome`, `ProtectSystem=strict`, `PrivateDevices`, and `NoNewPrivileges` remained active.
- The accepted archive is `aspen1-britton-desktop-2026-07-24T20:48:20`. Its complete Radicle-state manifest is BLAKE3 `480aa43cba75d5b1176b65df9a0f69c4a11ba8b36b426210914bc45ccdcadde0`, covering 303,134 records and 57,970,493,900 bytes. Its staged recovery-input manifest is BLAKE3 `f24d9e0a56109ae71570e8b8c4116448e340053380f72dd5f91d25ff071d2610`, covering six records and 72,341,285 bytes.
- The archive reported 58.04 GB original size, 57.62 GB compressed size, and 23.72 MB new deduplicated data relative to the preceding full archive. The incremental run completed with status zero in 3 minutes 21 seconds.
- `radicle-backup-restore-verify` extracted that archive into a clean root, regenerated and byte-compared both manifests, recovered node ID `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`, recovered fingerprint `SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE`, found all 6,760 repository directories, printed `restore_result=verified`, and exited zero.
- The complete manifest compares every persisted path, file and symlink byte, mode, UID, and GID. That byte-exact state comparison covers stored repository IDs, Git objects and refs, signed refs, identity refs, issue and patch COB data, and any declared custom COB refs without promoting them to semantic-validity claims.
- Positive and negative Rust tests cover deterministic component ordering, non-UTF-8 names, content and permission mutation, extra files, malformed hashes, and traversal. The live restore first exposed and rejected an invalid raw-byte ordering assumption; the corrected component-order fixture passed before the accepted restore.
- After backup and restore, all Radicle services and the policy timer were active, plaintext staging and the clean restore root were absent, and the recurring backup timer was enabled and active. Aspen1's accepted recovery closure was `/nix/store/4g55sgg0h7w2izpsajh7xyjnjlx6j8jq-nixos-system-aspen1-26.11.20260629.7a1a647`.

## Negative observations and bounded blockers

- The first activation rejected a newly generated identity because it did not match the persisted fingerprint. This was the correct fail-closed behavior and led to recovery rather than state deletion or identity rotation.
- The HTTP gateway is intentionally loopback-only. Stable DNS/TLS and a repository allowlist have not been admitted, so HTTPS exact-object acquisition has not passed.
- The inherited 56 GiB store has not yet been classified against the public repository allowlist. It MUST NOT be exposed through a public explorer or a wildcard Git gateway; the exact-route proxy currently has no production RID or public origin.
- Exact-object native acquisition from an independent Radicle client, exact-object HTTPS Git acquisition, unauthorized-repository behavior at the future proxy, and writable-operation rejection remain open. Off-host encrypted backup, clean restore, and Radicle node identity key recovery passed; per-pilot RID semantic probes remain blocked until a real pilot RID is admitted.
- This observation does not prove high availability, a second failure domain, repository correctness, delegate authority, CI isolation beyond the observed unit boundary, release readiness, private-repository confidentiality, or complete recovery.
