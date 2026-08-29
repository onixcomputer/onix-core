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

The provider wrapper polls only the admitted source view for the exact event commit. The source-refresh path grants read access to new pack files without exposing Radicle identity or network authority. If the wait expires, stop the broker and retain that failed state. Do not bypass the source view.

## Claim boundary

Machine evaluation and direct shadow runs do not prove CI correctness, source trust, host sandboxing, external provider truth, storage-device persistence, distributed exactly-once execution, production availability, or release eligibility. Live evidence remains bounded to its exact closure, event, state roots, and reports.
