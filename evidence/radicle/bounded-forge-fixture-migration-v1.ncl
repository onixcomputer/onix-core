# Canonical typed receipt for the controlled Bounded Exec forge fixture migration.
# Export with: nickel export --format json evidence/radicle/bounded-forge-fixture-migration-v1.ncl
let Digest = String in
let Record = {
  source_key | String,
  source_record_blake3 | Digest,
  target_type | String,
  target_object_id | String,
  target_ref_oid | String,
  observed_state_blake3 | Digest,
}
in
let Receipt = {
  schema_version | Number,
  receipt_type | String,
  status | String,
  observed_date | String,
  scope | String,
  implementation
    | {
      valence_revision | String,
      profile_blake3 | Digest,
      signed_refs_feature | String,
    },
  repository
    | {
      rid | String,
      importer_did | String,
      canonical_before | String,
      canonical_after | String,
      importer_sigrefs | String,
      importer_sigrefs_feature | String,
    },
  plan
    | {
      source_batch_blake3 | Digest,
      plan_blake3 | Digest,
      binding_receipt_blake3 | Digest,
      record_count | Number,
      records | Array Record,
    },
  idempotent_replay
    | {
      source_batch_blake3 | Digest,
      plan_blake3 | Digest,
      binding_receipt_blake3 | Digest,
      decisions | String,
      changed_ref_count | Number,
    },
  convergence
    | {
      local | Bool,
      aspen | Bool,
      desktop | Bool,
      public_https | Bool,
      aspen_node | String,
      desktop_node | String,
    },
  artifact_file_blake3
    | {
      source_batch | Digest,
      migration_plan | Digest,
      native_observations | Digest,
      migration_binding | Digest,
      replay_source_batch | Digest,
      replay_plan | Digest,
      replay_observations | Digest,
      replay_binding | Digest,
    },
  evidence | Array String,
  non_claims | Array String,
}
in
let receipt | Receipt = {
  schema_version = 1,
  receipt_type = "onix.radicle-forge-fixture-migration.v1",
  status = "accepted",
  observed_date = "2026-07-26",
  scope = "reviewed-controlled-fixture-not-source-export",
  implementation = {
    valence_revision = "e822bdf5395d6e1a77786c538ac0aaa13ef8c165",
    profile_blake3 = "1ca1407a5aa4e3fa0d503bcbb02cb8e45363cabddabee6e6cbeb1a3bdbe1d19d",
    signed_refs_feature = "parent",
  },
  repository = {
    rid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo",
    importer_did = "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx",
    canonical_before = "1baa4f552ae55923b025d99d08073286158836be",
    canonical_after = "1baa4f552ae55923b025d99d08073286158836be",
    importer_sigrefs = "d13faa9620a139c0eedc15eb4565e35934858c1c",
    importer_sigrefs_feature = "parent",
  },
  plan = {
    source_batch_blake3 = "7ff25bc2ba54fac61da36b0bb6f4b5755cef7fe3eecc7a54d2722d6d6ce5e135",
    plan_blake3 = "3c18f68c5c6a1cd6307052d9e9b5a42c2c0ac1a2f8bd24018a0f43666a1380eb",
    binding_receipt_blake3 = "1c7a5e7feaf223a7b0dddd8e5e4d8bc50092ce0b977681633e65d2035406ecbf",
    record_count = 2,
    records = [
      {
        source_key = "github:OnixResearch/bounded-exec:issue:1",
        source_record_blake3 = "3588369eaeda47ee3fdfcb81178407047011f48b7c482aba735541ad613268cc",
        target_type = "xyz.radicle.issue",
        target_object_id = "d9f9c0ad2da34c8cdd95ec0ad2f741de7361c76d",
        target_ref_oid = "de02d0257d181fc61662fa8e028b2296c5b30f8f",
        observed_state_blake3 = "d4276833c225d3dd50debd3e034dc89b638287505da6ac9e33811c16e552c2f7",
      },
      {
        source_key = "github:OnixResearch/bounded-exec:pull_request:2",
        source_record_blake3 = "930e2c5ad012946249f97811ed7a72d2bc4ab34b74cef015516ca1341d91ad7e",
        target_type = "xyz.radicle.patch",
        target_object_id = "86c2607da3e4960e173f4de56f776a291574c5e1",
        target_ref_oid = "97309eba9aed4ddb77934a4a49efd8c840e3be26",
        observed_state_blake3 = "71d1ddfc4bdbc7c34b2938af170919467abb6509ea30f79ccc6a25799e43f882",
      },
    ],
  },
  idempotent_replay = {
    source_batch_blake3 = "586b0fecb003d2ee35e21b7af61658d1b1bb34f60e0da5f7a33cf74293fefb60",
    plan_blake3 = "9d2e52a2f69f9df32610450e9689d19bd239e2643b3b34e631845332c970ff74",
    binding_receipt_blake3 = "536c2f4af3f671669f3614e9481ba72a04339ab96ac0b3e9fec1a7038f5a24bf",
    decisions = "verify-existing-for-both-records",
    changed_ref_count = 0,
  },
  convergence = {
    local = true,
    aspen = true,
    desktop = true,
    public_https = true,
    aspen_node = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8",
    desktop_node = "z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG",
  },
  artifact_file_blake3 = {
    source_batch = "a85202fe83ce4994aee6ee4487c53d52d2b474aa37192d41b30f4d41aa3d9e07",
    migration_plan = "d240e3f841ba10c17585f06d1096bdda2947b230ead3a8297aa3488b5db0fcd6",
    native_observations = "fd2c78154e6cd502b6aa0c814ac97db35ea41a4894359b6e6d2167d740026500",
    migration_binding = "099decd18d10d6f8d9069b741b35e6750597da83cd0f90d0449f6462c6cae189",
    replay_source_batch = "81a944cd75f48e12a6f39a132a4bc9bbc988da0267149a7f6ceca81851a7dd64",
    replay_plan = "9af940997ee7d22106fada199b8f4838af56248334fac6f77a5dd2dd9c63bc87",
    replay_observations = "2f4df6660877b2fe0968e2a4380f27ea49b60ca4764f87ebcdfceabbfbdb5cb8",
    replay_binding = "867a3859c31b576581688609c5ce9445162237666f172d341d56adc44c25348a",
  },
  evidence = [
    "evidence/radicle/bounded-forge-fixture-migration/source-batch.json",
    "evidence/radicle/bounded-forge-fixture-migration/migration-plan.json",
    "evidence/radicle/bounded-forge-fixture-migration/native-observations.json",
    "evidence/radicle/bounded-forge-fixture-migration/migration-binding.json",
    "evidence/radicle/bounded-forge-fixture-migration/source-batch-replay.json",
    "evidence/radicle/bounded-forge-fixture-migration/replay-plan.json",
    "evidence/radicle/bounded-forge-fixture-migration/replay-observations.json",
    "evidence/radicle/bounded-forge-fixture-migration/replay-binding.json",
  ],
  non_claims = [
    "controlled fixture migration does not claim GitHub export completeness, source actor authenticity, original signature or timestamp preservation, or semantic equivalence",
    "imported review text is attribution-only and does not create Radicle approval, delegate authority, merge eligibility, or canonical-ref authority",
    "seed and HTTPS convergence do not prove CI correctness, release readiness, post-update durability, or whole-stack GitHub independence",
    "this receipt records no canonical compare-and-swap and grants no canonical authority to Valence, seeds, the CI bot, or the runner",
  ],
}
in
receipt
