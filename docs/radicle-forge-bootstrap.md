# Radicle forge bootstrap operations

This runbook operates the single accepted Aspen1 bootstrap seed. Its canonical machine-readable receipt is [`evidence/radicle/bootstrap-v1.json`](../evidence/radicle/bootstrap-v1.json), with BLAKE3 in [`bootstrap-v1.blake3`](../evidence/radicle/bootstrap-v1.blake3).

## Claim boundary

Aspen1 replicates explicitly admitted public repositories and provides read-only HTTPS Git upload-pack access. The Radicle services have only the machine-scoped node key and repository storage. They do not receive delegate, canonical-ref, CI, deployment, release-signing, cache-write, artifact-administration, Cloudflare, GitHub, Buildbot, Nix-signing, Vaultwarden, or Matrix authority.

This bootstrap does **not** prove independent-seed availability, single-seed-outage survival, private-repository confidentiality, source correctness, review correctness, CI isolation beyond the observed service boundary, canonical-ref enforcement, release readiness, whole-stack GitHub independence, or geographic/building-power independence.

## Deploy and start

Build the selected machine before deployment:

```console
nix build .#nixosConfigurations.aspen1.config.system.build.toplevel --no-link -L
```

Deploy only through the reviewed target and strict host-key checking:

```console
nix develop -c clan machines update aspen1 \
  --target-host root@aspen1.local \
  --host-key-check strict \
  --upload-inputs
```

Verify the service set:

```console
ssh -o HostKeyAlgorithms=ssh-ed25519 root@aspen1.local \
  'systemctl is-active radicle-node.service radicle-httpd.service radicle-policy-reconcile.timer nginx.service cloudflared-tunnel-aspen1-services.service borgbackup-job-britton-desktop.timer'
```

Run policy reconciliation after an admission change:

```console
ssh -o HostKeyAlgorithms=ssh-ed25519 root@aspen1.local \
  'systemctl start radicle-policy-reconcile.service && journalctl -u radicle-policy-reconcile.service -n 20 --no-pager'
```

The final line must report the exact declared repository count. A non-zero service result or unexpected addition/removal blocks publication.

## Monitoring

Prometheus must retain these loaded alerts:

- `RadicleNodeNotActive`
- `RadicleHttpdNotActive`
- `RadiclePolicyReconcileFailed`

Inspect service and alert state without reading credentials:

```console
ssh -o HostKeyAlgorithms=ssh-ed25519 root@aspen1.local \
  'systemctl status radicle-node.service radicle-httpd.service radicle-policy-reconcile.timer --no-pager; journalctl -u radicle-node.service -u radicle-httpd.service -u radicle-policy-reconcile.service -n 100 --no-pager'
```

Expected listeners are native Radicle on `100.100.103.95:8776`, `radicle-httpd` on `127.0.0.1:8080`, and the Cloudflare-only Nginx origin on `127.0.0.1:8081`. Any wildcard Radicle/HTTP listener or direct public plaintext origin is an incident.

## Backup

The recurring job writes encrypted Borg archives to the restricted `britton-desktop` repository. Run an on-demand backup only after checking that no earlier job is active:

```console
ssh -o HostKeyAlgorithms=ssh-ed25519 root@aspen1.local \
  'systemctl is-active borgbackup-job-britton-desktop.service || systemctl start borgbackup-job-britton-desktop.service'
```

Then inspect bounded status:

```console
ssh -o HostKeyAlgorithms=ssh-ed25519 root@aspen1.local \
  'systemctl show borgbackup-job-britton-desktop.service -p Result -p ExecMainStatus --no-pager; journalctl -u borgbackup-job-britton-desktop.service -n 100 --no-pager'
```

Acceptance requires status zero, service resumption, deterministic state and recovery-input manifests, and removal of plaintext staging under `/run`.

## Restore verification

Run the clean-root verifier from Aspen1 in a captured operator session:

```console
ssh -o HostKeyAlgorithms=ssh-ed25519 root@aspen1.local \
  'radicle-backup-restore-verify'
```

Accept only exit status zero and `restore_result=verified` with matching complete manifests, node ID, fingerprint, repository count, and cleanup. Manifest equality proves byte-exact persisted state, not arbitrary repository semantics.

## Incident response and rollback

1. Remove the affected RID from both `seedRepositories` and `httpsGitRepositories` in `inventory/services/services.ncl`.
2. Build `checks.x86_64-linux.radicle-node-policy` and the Aspen1 system closure.
3. Deploy through `root@aspen1.local` with strict host-key checking.
4. Start `radicle-policy-reconcile.service`; verify the RID was removed and public HTTPS returns `404`.
5. Preserve redaction-safe service, proxy, policy, and manifest evidence; do not copy private keys or raw credential environments into an incident record.

For a bad system closure, switch Aspen1 to the last accepted generation through the normal NixOS rollback mechanism, then rerun service, exact-object, rejection, monitoring, backup, and restore checks. Do not roll back by deleting `/var/lib/radicle`, replacing the node key, or editing generated lock files.

## Package upgrade

A Radicle upgrade must update the reviewed package version and source identity together, pass positive and negative policy fixtures, and preserve signed-reference feature `parent` or stronger. Build the focused check and Aspen1 closure before deployment. After deployment, repeat node-ID/fingerprint continuity, controlled restart, native exact-object acquisition, HTTPS exact-object acquisition, undeclared-RID rejection, write rejection, monitoring, backup, and clean restore.

## Node-key loss

Do not generate a replacement key for the inherited Aspen1 state. Stop public admission, retain the encrypted Borg repository, and use the clean restore flow to recover the staged private/public key pair and generated `config.json`. Accept recovery only when the restored public/private pairing yields fingerprint `SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE` and node ID `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`. A different fingerprint or node ID is a failed recovery and must not be announced.
