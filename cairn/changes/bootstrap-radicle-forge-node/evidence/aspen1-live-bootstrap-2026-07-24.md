# Aspen1 live bootstrap observation — 2026-07-24

## Scope

This bounded observation records the first activation of the reviewed Radicle service on Aspen1. It is deployment evidence, not the final deterministic bootstrap receipt.

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

## Negative observations and bounded blockers

- The first activation rejected a newly generated identity because it did not match the persisted fingerprint. This was the correct fail-closed behavior and led to recovery rather than state deletion or identity rotation.
- The HTTP gateway is intentionally loopback-only. Stable DNS/TLS and a repository allowlist have not been admitted, so HTTPS exact-object acquisition has not passed.
- The inherited 56 GiB store has not yet been classified against the public repository allowlist. It MUST NOT be exposed through a public explorer or a wildcard Git gateway; the exact-route proxy currently has no production RID or public origin.
- Exact-object native acquisition from an independent Radicle client, exact-object HTTPS Git acquisition, unauthorized-repository behavior at the future proxy, writable-operation rejection, off-host backup, clean restore, and key-loss recovery remain open.
- This observation does not prove high availability, a second failure domain, repository correctness, delegate authority, CI isolation beyond the observed unit boundary, release readiness, private-repository confidentiality, or complete recovery.
