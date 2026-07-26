# Typed policy contract for the explicit Bounded Exec canonical compare-and-swap guard.
let EmptyLength = 0 in
let MinimumPositive = 1 in
let ExpectedSchema = "onix.radicle-forge-guard.v1" in
let ExpectedStatusSchema = "onix.radicle-ci-status.v1" in
let ExpectedAdmissionSchema = "valence.radicle-forge-operations.ci-admission.v1" in
let ExpectedEventSchema = "onix.radicle-ci-event.v1" in
let ExpectedResultSchema = "onix.radicle-ci-result.v1" in
let ExpectedRid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo" in
let ExpectedPolicyBlake3 = "091e57f4409f79db14465ccc26e730bf1181209fe45c28d7dd1259393e93f740" in
let ExpectedValenceRevision = "e822bdf5395d6e1a77786c538ac0aaa13ef8c165" in
let ExpectedBotDid = "did:key:z6MknopLULJensBT5KGkC8h9KaHTNY5muZ9UffqroErX7Rni" in
let ExpectedDelegates = [
  "did:key:z6MkjCqx5ksRqcDeNeuEnz53udbUHebRLHhddCxecWJu9koE",
  "did:key:z6MkmkA6sEzzMffaWqKEKJcDh8LjAzgrJLrTNi971KN3X6sh",
  "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx",
]
in
let ExpectedThreshold = 2 in
let ExpectedCheckName = "onix/ci/v1" in
let ExpectedTargetRef = "refs/heads/main" in
let ExpectedFeature = "parent" in
let ExpectedAdmissionNonClaims = [
  "migration records normalized source metadata and observed native COB state; it does not prove source export completeness, source actor authenticity, original signature or timestamp preservation, or semantic equivalence",
  "imported review metadata is recorded attribution only and does not create Radicle approval, merge eligibility, delegate authority, or canonical-ref authority",
  "CI admission is bounded input for an external guarded compare-and-swap; it is not protocol-enforced mandatory CI, bypass-proof delegate behavior, canonical mutation, CI correctness, or release readiness",
]
in
let ExpectedGuardNonClaims = [
  "guard admission does not provide Radicle protocol-enforced mandatory CI, bypass-proof delegate behavior, or merge semantics",
  "guard execution does not grant canonical authority to the CI bot, credentialless runner, seeds, or Valence",
  "guard execution receipt does not prove CI correctness, seed convergence, replication, release readiness, or post-update durability",
]
in
let Exact = fun expected => std.contract.from_predicate (fun value => value == expected) in
let NonEmptyString =
  std.contract.from_predicate (fun value =>
    std.is_string value && std.string.length value > EmptyLength
  )
in
let PolicyShapeContract = {
  schema | Exact ExpectedSchema,
  status_schema | Exact ExpectedStatusSchema,
  admission_schema | Exact ExpectedAdmissionSchema,
  event_schema | Exact ExpectedEventSchema,
  result_schema | Exact ExpectedResultSchema,
  rid | Exact ExpectedRid,
  ci_policy_blake3 | Exact ExpectedPolicyBlake3,
  valence_revision | Exact ExpectedValenceRevision,
  bot_did | Exact ExpectedBotDid,
  delegates | Array NonEmptyString,
  threshold | std.contract.from_predicate (fun value => std.is_number value && value >= MinimumPositive),
  required_check | Exact ExpectedCheckName,
  target_ref | Exact ExpectedTargetRef,
  signed_refs_feature | Exact ExpectedFeature,
  admission_non_claims | Array NonEmptyString,
  required_non_claims | Array NonEmptyString,
}
in
let exact_policy = fun policy =>
  policy.delegates == ExpectedDelegates
  && policy.threshold == ExpectedThreshold
  && policy.admission_non_claims == ExpectedAdmissionNonClaims
  && policy.required_non_claims == ExpectedGuardNonClaims
in
let GuardPolicyContract = std.contract.from_predicate exact_policy in
{
  PolicyShape = PolicyShapeContract,
  GuardPolicy = GuardPolicyContract,
  expected = {
    schema = ExpectedSchema,
    status_schema = ExpectedStatusSchema,
    admission_schema = ExpectedAdmissionSchema,
    event_schema = ExpectedEventSchema,
    result_schema = ExpectedResultSchema,
    rid = ExpectedRid,
    ci_policy_blake3 = ExpectedPolicyBlake3,
    valence_revision = ExpectedValenceRevision,
    bot_did = ExpectedBotDid,
    delegates = ExpectedDelegates,
    threshold = ExpectedThreshold,
    required_check = ExpectedCheckName,
    target_ref = ExpectedTargetRef,
    signed_refs_feature = ExpectedFeature,
    admission_non_claims = ExpectedAdmissionNonClaims,
    required_non_claims = ExpectedGuardNonClaims,
  },
}
