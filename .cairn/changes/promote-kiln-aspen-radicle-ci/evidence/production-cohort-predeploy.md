# Production cohort predeployment

Date: 2026-08-28

## Immutable inputs

- durable Kiln host and provider: `ccf6c64e8cba1d77299eab1386788426fa63e43e`;
- retained canary Kiln: `69c0a6ac454d7291e4aed12fd72a6f2c31636e76`;
- retained legacy broker Kiln: `8821e9adf15ad28838025bfbdd2e09c8d76fe5db`;
- production Lattice application runtime: `feb16b911a23e36d22d1359e44a9bc6b692cc98c`;
- frozen canary Lattice application runtime: `c513d94d89e901ffa56ae67f375f973e55958e42`;
- Lattice workflow contract: `70496e67c7fd4a8b05914161a8e09de2759bebc8`;
- Bounded Exec: `29dac88ecded94457572db3fdfaaaab95fa91525`;
- Durable File Publication: `8e05e74e24b45f752d77145c4455385daaf6d6ab`.

The canary, production cohort, and legacy broker now use separate immutable Kiln inputs.

## Exact route

The production workflow revision is `b3:616b5d8beb00044accf14e88c3d71b487669535e6dbf54c02fc2c4929fbc3e4a`. The reviewed Kiln workflow profile and graph identities remain:

- profile `b3:67f30a749eaa91b56a5a0e42873c9b13968ff92ae87f577c6f36041f4a722cb5`;
- graph `b3:a5af82f6dc0f5b094624022825ba048775cc4892bfdd12473bb57945e8745426`.

The first status-disabled shadow attempt was retained as operation `91ab5c42...` with state `Unknown`. A raw contract exchange proved that Lattice returned `InvalidContract` before acceptance, and no provider process or report existed. The cause was a stale route revision after UID-bound provider profile paths changed the workflow command. The production workflow now uses stable `/run/current-system` and `/etc` command paths.

The second status-disabled attempt, operation `690a355c...`, also received `InvalidContract` before provider acceptance. The marker named `616b`, but a store export proved the stored workflow still had revision `e86f`. The Lattice pre-start now re-imports the exact workflow on every start after it validates the marker.

The third attempt, operation `d43a8b6f...`, reached the provider. Its profile report bound was four KiB below the admitted stdout, stderr, and report-header sum, so the provider exited with code `2` before Nix. Lattice runtime `c513d94...` incorrectly projected that nonzero typed exit as success. Runtime `feb16b9...` makes workflow exchange classify nonzero, missing, duplicate, or malformed typed exit output as terminal failure. The provider report bound is now 17 MiB. All three failed host roots and the false-success Lattice state are retained under the root-only quarantine directory. A fourth exact trigger identity will run the corrected shadow; none of the prior operations is redispatched.

The provider profile binds UID `975`, RID `rad:z3xXXCQXCTquvAawh41YYs8yC8xmk`, the exact source view, wrapper BLAKE3, working directory, report view, report namespace, HTTPS URL, and every process and publication bound.

## Authority

The production host uses UID `974`. Lattice and the provider use UID `975`. They do not reuse canary identities.

The first pre-shadow activation exposed that the proposed UIDs `972` and `973` already belonged to `pcscd` and `mandb`. No shadow request had run. The production services were stopped, and only their new state, runtime, and report directories were removed. The revised module uses unused UIDs and asserts that each UID has exactly one account owner before activation.

Four groups keep authority separate:

- ingress: broker and host;
- internal: host and Lattice;
- source: Lattice only;
- reports: Lattice and the report reader.

The broker is not in the internal or source groups. The host is not in the source or report groups. The ingress and internal sockets use different directories.

The Lattice mount namespace binds only the admitted Seaglass bare repository as read-only. It binds only the dedicated report directory as writable. `/var/lib/radicle`, `/var/lib/radicle-ci`, homes, secrets, SSH state, the Aspen host state, and the ingress socket directory remain inaccessible.

A root oneshot grants a read-only default ACL only on the admitted repository. It rejects links and non-file members. It has no network namespace and only the capabilities needed to update that ACL.

## Route selection

`routeMode` accepts only `shadow`, `aspen`, or `legacy`. The committed value is `shadow`, so the active broker remains the legacy command. The `aspen` value selects one explicit `--protocol defelo --runtime aspen` command and clears legacy environment. No failure changes the selection.

## Checks

The focused Nickel profile check, module authority check, retained canary check, legacy continuity check, and full machine evaluation pass. Negative fixtures reject relative provider paths, malformed workflow identities, expanded source paths, overlapping source and report views, canary UID reuse, zero bounds, and unknown route modes.

This evidence describes configuration and build facts. It does not prove deployment, live source readability, report delivery, broker cutover, CI correctness, host sandboxing, storage-device persistence, distributed exactly-once execution, production availability, or release eligibility.
