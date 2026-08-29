# CI parity gap list — GitHub Actions rails vs Seaglass flake checks

Observed from `.github/workflows/ci.yml` (nine jobs) against
`checks.x86_64-linux` of the Seaglass flake.

## Covered by existing flake checks

- `architecture-dependency-guard` job → `checks.architecture-dependency-guard`
- `nix-and-dx-builds` job → `nix flake show --json` (eval) and
  `checks.dx-web-build`
- `octet-deny-all` job → `checks.octet`, `checks.octet-validation-polars`
- workspace clippy → `checks.clippy`
- lifecycle/metadata rails → `checks.cairn-traceability`,
  `checks.cairn-artifact-source-routing` and the accepted Cairn specs
  (OpenSpec lifecycle scripts are retired with the OpenSpec directory)

## Newly expressed as hermetic flake checks (this change)

- harness-matrix metadata → `checks.harness-matrix`
- browser E2E default rail metadata → `checks.browser-e2e-default-rail`
- workspace nextest rail metadata → `checks.workspace-nextest-rail`
- `checks.parity-gap-check` pins the named rails so removing one fails
  evaluation

## GitHub-only rails remaining (execution parity follow-up)

- workspace nextest EXECUTION (`cargo nextest run --workspace -P ci`) —
  needs the hermetic workspace cargo-test sandbox (vendored crates-io and
  git dependencies plus CARGO_HOME population) before it can run inside
  the network-isolated CI provider
- browser E2E default rail EXECUTION
  (`run-browser-e2e-default-rail.sh`) — same sandbox requirement plus a
  headless browser
- steel runtime examples EXECUTION
  (`cargo test -p seaglass-runtime --features steel-engine --examples`) —
  same sandbox requirement
- example fixture EXECUTION (`check-example-fixture-execution.sh` —
  nextest over `seaglass-runtime-fixtures` and three `seaglass-cli` test
  targets) — same sandbox requirement
- generated artifact REGENERATION step
  (`generate_constants.sh` shells out to `cargo run`) — the drift
  comparison is hermetic, the regeneration is not

Because of those remaining execution rails, `ci.yml` stays in place until
the hermetic test sandbox lands; retiring it now would lose test
execution entirely.
