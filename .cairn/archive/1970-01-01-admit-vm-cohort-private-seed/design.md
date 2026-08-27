## Context

The Radicle node and two replicas reconcile an exact private repository list every five minutes. They unseed all private RIDs outside that list.

VM Cohort canonical `main` points to stable lifecycle evidence revision `31f1696ba9391bfda8577a58af84f72361d5573e`. No admitted seed currently advertises the RID.

## Decisions

### Decision: Admit one exact private RID through every policy mirror

**Choice:** Add a named VM Cohort RID constant to the service inventory, node check, replica check, node validator, and replica validator.

**Rationale:** These five locations jointly prevent inventory drift and hand-edited runtime exceptions.

### Decision: Keep native private transport only

**Choice:** Add VM Cohort only to `privateSeedRepositories`.

**Rationale:** Private mechanism source must not enter the public HTTP or HTTPS repository set.

### Decision: Treat seed observation as availability evidence only

**Choice:** Record exact canonical and advertised refs without promoting them to trust or release authority.

**Rationale:** Replication shows bounded availability. It does not prove source correctness, identity trust, or future reachability.

## Risks / Trade-offs

- Every admitted seed stores another private repository.
- A missed policy mirror would fail focused checks.
- A failed deployment leaves the source locally current but not independently replicated.
- Seed availability does not authorize downstream adoption or release.
