# Verification evidence

Date: 2026-08-27

## Policy admission

VM Cohort RID `rad:z2QJLUqyAZnnHPiZQ1BFjLsX9ush3` is present in:

- `inventory/services/services.ncl`;
- `flake-outputs/_radicle-node-checks.nix`;
- `flake-outputs/_radicle-seed-replica-checks.nix`;
- `modules/radicle-node/validate-settings.nix`;
- `modules/radicle-seed-replica/validate-settings.nix`.

The RID is present only in the private source set. It is absent from public seed and HTTPS publication sets.

## Static checks

Passed:

```text
ncl export inventory/services/services.ncl
nix build .#checks.x86_64-linux.radicle-seed-replica --no-link -L --accept-flake-config --no-pure-eval --option allow-import-from-derivation true
```

The replica check covers positive and negative settings validation, policy reconciliation, identity verification, and private/public class separation.

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

## Fleet deployment and private replication

Primary, desktop, and Aspen3 policy reconciliation completed with `desired=10`.
The Radicle node and policy timer are active on Aspen3.
Aspen3 uses node ID `z6MkoHdimfedLwXjNZhxfAadc8H3rW2TMjpn7ATMNcRWieWh` at `100.108.13.4:8776`.

The Aspen3 deployment activated NixOS system `/nix/store/5d6ylm62whfkrklb1pidv81nyni9v81w-nixos-system-aspen3-26.11.20260819.afe3d8a`.
The deployment retained the expected node identity and added the VM Cohort RID to the exact ten-repository private policy.

The operator bootstrapped Aspen3 from the canonical local Radicle storage while the node was stopped.
The target was absent before the transfer.
The node restarted before policy reconciliation.
Git object verification on Aspen3 resolved commit `31f1696ba9391bfda8577a58af84f72361d5573e` exactly.

Private repositories do not enter the public inventory.
An explicit known-seed clone therefore supplied the independent reachability check.
From `britton-desktop`, the user node connected directly to the Aspen3 node and ran a bare private clone with that seed identity.
Radicle reported one preferred seed and a successful clone.
The independently materialized desktop storage resolved commit `31f1696ba9391bfda8577a58af84f72361d5573e` exactly.

The original desktop storage was held aside during this check and restored automatically on failure.
The successful clone replaced it only after exact object verification.
The temporary checkout was removed after verification.

## Bounded conclusion

The maintained private policy admits VM Cohort on all three seed targets.
Aspen3 stores the repository and serves a direct private clone of the canonical revision.
A second host materialized and verified that revision through the explicit private-seed path.

This evidence does not make the RID public.
It does not prove source correctness, remote trust, future availability, adoption authority, or release eligibility.
The initial Aspen3 content bootstrap was an operator-controlled transfer; policy reconciliation and direct-clone evidence are separate observations.
