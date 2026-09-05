# Kiln Aspen Radicle CI

This module stages the production Seaglass CI cohort. It does not change the broker route by itself.

The cohort runs three boundaries:

- the `kiln-aspen-ci-host` user owns durable Aspen and Kiln operation state;
- the `kiln-aspen-ci-lattice` user owns Lattice state and runs the bounded Nix provider;
- the existing `radicle` user can connect only to the Aspen ingress socket and read published reports.

The host and Lattice sockets use different directories and groups. The broker cannot connect to the Lattice socket. The host cannot read the source view or report root.

A root oneshot applies a read-only ACL to the exact Seaglass bare repository. A path unit reapplies this ACL after Git pack or master-reference changes. The Lattice mount namespace binds only that repository to the configured source view. It hides `/var/lib/radicle`, keys, node sockets, policy state, home directories, secrets, and the Aspen ingress directory.

The provider receives a cleared environment. It runs one fixed `nix flake check --no-update-lock-file` wrapper with finite output, time, polling, and process-group teardown bounds. It publishes no-replace `0640` logs and reports into a setgid report group.

## Staging

The operator-only `kiln-aspen-ci-shadow.service` has no target dependency. It sends one fixed native trigger through the production host without publishing a Radicle status. The operator-only `kiln-aspen-ci-authority-probe.service` runs with the Lattice mount policy and verifies the exact source, read-only source access, writable report view, hidden authority paths, socket separation, and Nix daemon endpoint. The `routeMode` setting accepts only `shadow`, `aspen`, or `legacy`. `shadow` and `legacy` retain the separately pinned legacy command. `aspen` selects the explicit Defelo-over-Aspen command and clears legacy adapter environment. No failure changes this setting automatically.

## Operations

### Status and alerts

Check these units after each switch and at each incident start:

```console
systemctl is-active radicle-ci-broker.service kiln-aspen-ci-host.service kiln-aspen-ci-lattice.service kiln-aspen-ci-source-admission.service kiln-aspen-ci-source-refresh.path radicle-ci-reports.service
systemctl show kiln-aspen-ci-source-refresh.service -p Result -p ExecMainStatus
```

Alert when a required unit is inactive or restart-looping. Also alert on a non-empty broker queue, source-refresh failure, source-readiness exhaustion, report publication failure, or a leftover provider process. A terminal Nix failure can be a valid CI result. Do not classify it as a route failure without its report.

### Drain and cutover

Stop the broker before each route change. Confirm that it has no adapter child and that `ci_event_queue` is empty. Record the broker database BLAKE3 before and after the stop. Start the broker only after the host, Lattice, source admission, source-refresh path, report server, sockets, and authority probe pass.

### Backup and restore

Stop the broker, host, and Lattice before copying state. Save file-level BLAKE3 manifests with each root-only backup. Restore only a verified backup with a known operation state. Never restore corrupt, uncertain, false-success, or quarantined state as current evidence. Use `systemd-tmpfiles` to create empty replacement roots.

### Upgrade

Keep the legacy and hosted inputs separate. Pin each reviewed revision and run the focused module, profile, continuity, machine, and Cairn checks. Drain the broker before deployment. After deployment, prove one real event, exact replay, restart replay, report serving, local status state, teardown, and explicit rollback.

### Rollback

Rollback is an explicit `routeMode = "legacy"` deployment. Do not select it from an Aspen failure. If an operation is pending or uncertain, stop and reconcile it first. Preserve hosted state, reports, hashes, and quarantine roots before the switch.

### Source visibility

The provider wrapper polls only the admitted source view for the exact event commit. The source-refresh path grants read access to new pack files without exposing Radicle identity or network authority.

The admission command reads current ACLs and updates only missing group entries. It must not rewrite current ACLs because attribute writes retrigger `PathModified`. One settling refresh can follow a repository update, but that run must make no further ACL changes.

If the path reaches its start limit, deploy the fixed closure before recovery. Then reset the failed service and path, start the admission service once, and start the path. If the provider wait expires, stop the broker and retain that failed state. Do not bypass the source view.

### Status propagation

The broker writes job status COBs into the seed storage and announces them, but its announce step fails with `no refs were announced` on status updates. The `kiln-aspen-ci-status-sync.path` unit watches the bot namespace signed-refs file and runs one bounded `rad sync` for the admitted repository after each write, so peers fetch the new status without operator action. If the sync unit fails, run `sudo -u radicle env HOME=/var/lib/radicle RAD_HOME=/var/lib/radicle rad sync <rid>` manually and inspect the unit before retrying. This propagation does not prove remote CI correctness or release eligibility.

### Radicle CLI profile repair

The Radicle CLI needs a loadable profile, but the node binds its public key and reads its secret key through systemd credentials, and fresh state leaves empty stubs at `/var/lib/radicle/keys/radicle`, `keys/radicle.pub`, and `config.json`. If `rad` reports `ssh keygen: length invalid` or a config parse error, restore the profile: install the node private key from the secrets store at mode `0600` owned by `radicle`, derive the public key with `ssh-keygen -y`, and copy the pinned node config from its store path to `/var/lib/radicle/config.json` at mode `0644`. Verify with `rad self` as the `radicle` user. The fingerprint must match `/var/lib/radicle/node/fingerprint`.

## Claim boundary

Machine evaluation and direct shadow runs do not prove CI correctness, source trust, host sandboxing, external provider truth, storage-device persistence, distributed exactly-once execution, production availability, or release eligibility. Live evidence remains bounded to its exact closure, event, state roots, and reports.
