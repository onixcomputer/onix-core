## ADDED Requirements

### Requirement: Exact private VM Cohort seed admission

r[onix.radicle.vm_cohort_private_seed] The fleet MUST admit VM Cohort RID `rad:z2QJLUqyAZnnHPiZQ1BFjLsX9ush3` through the exact private Radicle source policy and every maintained policy mirror. It MUST NOT add that RID to public HTTP or HTTPS publication sets.

#### Scenario: Complete private admission passes

- GIVEN the service inventory, node check, replica check, node validator, and replica validator
- WHEN private Radicle policy validation runs
- THEN all five locations MUST contain the same exact VM Cohort RID

#### Scenario: One policy mirror is missing

- GIVEN the VM Cohort RID is absent from one maintained private-source mirror
- WHEN focused validation runs
- THEN admission MUST fail before deployment

#### Scenario: Public route includes the private RID

- GIVEN VM Cohort appears in a public seed or HTTP publication set
- WHEN route-boundary validation runs
- THEN admission MUST fail

### Requirement: Bounded seed replication evidence

r[onix.radicle.vm_cohort_private_seed.evidence] Deployment evidence MUST bind the admitted RID and observed canonical VM Cohort revision. It MUST NOT claim source correctness, remote trust, future availability, adoption authority, or release eligibility.

#### Scenario: Exact seed observation passes

- GIVEN an admitted fleet node advertises VM Cohort revision `31f1696ba9391bfda8577a58af84f72361d5573e`
- WHEN replication verification runs
- THEN the receipt MUST report bounded private availability

#### Scenario: Seed observation is missing

- GIVEN no independent admitted node advertises the exact revision
- WHEN replication verification runs
- THEN durable replication MUST remain unproven
