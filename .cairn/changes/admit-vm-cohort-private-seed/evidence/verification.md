# Verification evidence

Date: 2026-08-27

## Policy admission

VM Cohort RID `rad:z2QJLUqyAZnnHPiZQ1BFjLsX9ush3` is present in:

- `inventory/services/services.ncl`;
- `flake-outputs/_radicle-node-checks.nix`;
- `flake-outputs/_radicle-seed-replica-checks.nix`;
- `modules/radicle-node/validate-settings.nix`;
- `modules/radicle-seed-replica/validate-settings.nix`.

The RID is present only in the private source set. It is not in the public seed or HTTPS publication sets.

## Checks

Passed:

```text
ncl export inventory/services/services.ncl
nix build .#checks.x86_64-linux.radicle-seed-replica --no-link -L --accept-flake-config --no-pure-eval --option allow-import-from-derivation true
```

The replica check includes positive and negative settings validation, policy reconciliation, identity verification, and private/public class separation.

Attempted:

```text
nix build .#checks.x86_64-linux.radicle-node-policy --no-link -L --accept-flake-config --no-pure-eval --option allow-import-from-derivation true
```

The node check reached its pre-existing package review gate and failed with:

```text
radicle-node version changed without updating the reviewed package identity
```

The same command produced the same failure on clean `origin/main` at `272081c5a068ed2dd01b927bef4f2ff1eb62e6f7`.

This change does not alter the Radicle package identity.

## Deployment status

Fleet deployment and independent seed observation remain pending.

The target VM Cohort canonical revision is `31f1696ba9391bfda8577a58af84f72361d5573e`.

## Non-claims

Policy admission does not prove deployment success, source correctness, remote trust, future availability, adoption authority, or release eligibility.
