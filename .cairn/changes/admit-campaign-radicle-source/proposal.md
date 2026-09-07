# Admit Campaign to the public Radicle forge

## Why

ChaosControl needs a reproducible Campaign dependency at revision `e23e3edf1dc6a8c612a4ea33a3b805bda1173e3b`.
The local publisher namespace contains that revision. The public HTTPS adapter rejects the repository, and no seed advertises it.

## What Changes

Add `rad:z2scC9MCm3pxk9mX4FEidRKabQ5LN` to the existing public source list.
Derive the Aspen1 HTTPS policy and all three seed policies from that list.
Keep private repositories, CI, delegates, credentials, and service ownership unchanged.
Add positive and negative checks for the exact policy change.
Deploy only after source checks and host-preservation checks pass.
Verify the exact source from a fresh HTTPS checkout and record native replication observations.

## Impact

Onix Core owns policy, deployment, and host observations. Campaign owns its source and publisher namespace.
ChaosControl remains the consumer and owns adapter acceptance and KVM evidence.
This change grants source-serving scope, not CI, delegate, release, or execution authority.
The user authorized this infrastructure admission and deployment in the current session.

## Durable Capability

The existing forge supplies a pinned source to a current consumer. No new serving framework or mirror is necessary.
Onix Core maintains the policy and checks. Fresh exact-revision acquisition supplies the repeatability evidence.

## Non-Claims

Source availability does not prove Campaign correctness, ChaosControl adoption, KVM parity, indefinite availability, or release readiness.
