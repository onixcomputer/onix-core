# Dependency preflight

## Reviewed revisions

- Onix Core base: `41596f3127bc1486dbc3a706724b928b705498dc`
- Aspen: `d50c91f2a825f4811404ba9d590626b636472ce5`
- Kiln: `96c7bc6a5ab7465c7763617ffb6a135fbe8332bf`
- Existing Onix Core Kiln input: `8821e9adf15ad28838025bfbdd2e09c8d76fe5db`

## Baseline evidence

The existing `seaglass-kiln-ci-policy` Nix check passed before this change.

Cairn validation passed with 17 existing active changes and no baseline issues.

## Findings

1. `britton-desktop` configures `kiln-adapter-radicle` without `--runtime aspen`.
2. Aspen publishes `NativeSystemExtensionService`, but no Unix host daemon for the Kiln client.
3. Kiln publishes `UnixAspenServiceTransport`, but no matching server.
4. Kiln's only concrete Aspen service is `LocalAspenService`, which is simulation.
5. Concrete Aspen workflow and remote transports exist only as test fixtures.
6. The archived cross-repository harness imports Aspen test support and uses in-memory recording adapters.
7. Aspen's provider completion carries an output reference without the provider output bytes.
8. Kiln therefore maps the hosted completion to `CallbackEffectTerminal::Unknown`.

## Decision

Do not enable or deploy an Onix Core service until Aspen and Kiln publish the missing contracts.

The selected route is a Kiln-owned host bridge over Aspen's generic host and Lattice's published workflow exchange.

## Resolved dependency cohort

Aspen revision `22f8ded26ca1907c29948e08b53f35df23080733` added exact materialized provider completion. It is published through canonical `molten` commit `6db000065959da2c94b91bd0adeeff1812b55e16`.

Kiln protocol revision `42eabcb21385a436ddc044fb7034b8cdaec7b8a0` added the exact hosted completion, Unix server protocol, Lattice effect mapping, and no-fallback client selection.

Kiln host revision `69c0a6ac454d7291e4aed12fd72a6f2c31636e76` adds the deployable standalone composition and pins the protocol revision above. Its Cairn package is synced and archived with clean Cargo, Nix, Octet, and local real-Lattice evidence.

Lattice contract revision `70496e67c7fd4a8b05914161a8e09de2759bebc8` does not build the full Lattice application. Runtime revision `c513d94d89e901ffa56ae67f375f973e55958e42` is the nearest later `main` revision that restores the required core modules. The workflow contract, transport, handler, and handler contract paths have no changes between these revisions.

A local cross-process run used the real Lattice application, real Aspen native service, and bounded Kiln extension process. Accepted execution reached `success`, exact replay matched, and the denied trigger released no provider effect. A provider endpoint then read one complete request and closed without a response. The first and repeated submissions both returned the same `aspen_ingress_unknown` classification without provider redispatch.

The dependency gate is now clear for the separate Onix Core module. This evidence does not establish deployment readiness or authorize archive before live drills pass.
