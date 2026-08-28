# Kiln Aspen Radicle CI

This module stages the production Seaglass CI cohort. It does not change the broker route by itself.

The cohort runs three boundaries:

- the `kiln-aspen-ci-host` user owns durable Aspen and Kiln operation state;
- the `kiln-aspen-ci-lattice` user owns Lattice state and runs the bounded Nix provider;
- the existing `radicle` user can connect only to the Aspen ingress socket and read published reports.

The host and Lattice sockets use different directories and groups. The broker cannot connect to the Lattice socket. The host cannot read the source view or report root.

A root oneshot applies a read-only ACL to the exact Seaglass bare repository. The Lattice mount namespace binds only that repository to the configured source view. It hides `/var/lib/radicle`, keys, node sockets, policy state, home directories, secrets, and the Aspen ingress directory.

The provider receives a cleared environment. It runs one fixed `nix flake check --no-update-lock-file` wrapper with finite output, time, polling, and process-group teardown bounds. It publishes no-replace `0640` logs and reports into a setgid report group.

## Staging

The operator-only `kiln-aspen-ci-shadow.service` has no target dependency. It sends one fixed native trigger through the production host without publishing a Radicle status. The operator-only `kiln-aspen-ci-authority-probe.service` runs with the Lattice mount policy and verifies the exact source, read-only source access, writable report view, hidden authority paths, socket separation, and Nix daemon endpoint. The `routeMode` setting accepts only `shadow`, `aspen`, or `legacy`. `shadow` and `legacy` retain the separately pinned legacy command. `aspen` selects the explicit Defelo-over-Aspen command and clears legacy adapter environment. No failure changes this setting automatically.

## Claim boundary

Machine evaluation and direct shadow runs do not prove broker cutover, CI correctness, source trust, host sandboxing, external provider truth, storage-device persistence, distributed exactly-once execution, production availability, or release eligibility.
