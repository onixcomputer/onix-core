let Receipt = {
  schema_version | Number,
  receipt_type | String,
  status | String,
  observed_date | String,
  repository
    | {
      rid | String,
      reviewed_commit | String,
      source_archive_blake3 | String,
      cairn_archive_receipt_blake3 | String,
    },
  governance
    | {
      identity_revision | String,
      delegates | Array String,
      threshold | Number,
      signed_refs_feature | String,
      publisher_sigrefs | String,
    },
  policy
    | {
      implementation_revision | String,
      public_rids | Array String,
      private_rids | Array String,
      https_rids | Array String,
      ci_rids | Array String,
    },
  deployment
    | {
      aspen_closure | String,
      desktop_closure | String,
      native_desired_count | Number,
      public_https_count | Number,
      runtime_overrides | String,
      desktop_bootstrap_transport | String,
    },
  probes
    | {
      aspen_native | String,
      desktop_native | String,
      https | String,
      unknown_rid | String,
      receive_pack | String,
      wrong_service | String,
      missing_object | String,
    },
  authority_boundary
    | {
      seed_credentials | Array String,
      delegate_credentials_absent | Bool,
      protect_home | Bool,
      no_new_privileges | Bool,
      capability_bounding_set_empty | Bool,
    },
  evidence | Array String,
  non_claims | Array String,
}
in
let receipt_schema_version = 1 in
let canonical_threshold = 1 in
let expected_native_desired_count = 5 in
let expected_public_https_count = 4 in
let bounded_exec = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo" in
let artifact_auth = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f" in
let execution_graph = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a" in
let durable_file_publication = "rad:z3tAR4For7qw8ZirkJzoDw1VNDDLM" in
let private_fixture = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg" in
let receipt | Receipt = {
  schema_version = receipt_schema_version,
  receipt_type = "onix.radicle-durable-file-publication-source-admission.v1",
  status = "accepted",
  observed_date = "2026-07-27",
  repository = {
    rid = durable_file_publication,
    reviewed_commit = "951c27f59003cea9bfdb40ed4d89653d50fada1f",
    source_archive_blake3 = "2c1d8b5adc8d7384f48a6f8336165e38c3eb196337ebbd66707e157a64b63210",
    cairn_archive_receipt_blake3 = "3a11ed34c922a32678f4e5e72bd9ea48b3e3d0eba35edf0c821c27f5a7920fe4",
  },
  governance = {
    identity_revision = "8d6d95454c09449708e687b51e80c787750e75e3",
    delegates = ["did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx"],
    threshold = canonical_threshold,
    signed_refs_feature = "parent",
    publisher_sigrefs = "8aa111383236ef76578edb18dbc5410395a42763",
  },
  policy = {
    implementation_revision = "8211b290622d7e8aa7f07198b125cd9169f59f0c",
    public_rids = [
      bounded_exec,
      artifact_auth,
      execution_graph,
      durable_file_publication,
    ],
    private_rids = [private_fixture],
    https_rids = [
      bounded_exec,
      artifact_auth,
      execution_graph,
      durable_file_publication,
    ],
    ci_rids = [bounded_exec],
  },
  deployment = {
    aspen_closure = "/nix/store/j2mvzq86wwdrgna1972av3cm868rq9ni-nixos-system-aspen1-26.11.20260629.7a1a647",
    desktop_closure = "/nix/store/8zr3fdh5sf16d8bxjpgkgc4cg1m9snid-nixos-system-britton-desktop-26.11.20260629.7a1a647",
    native_desired_count = expected_native_desired_count,
    public_https_count = expected_public_https_count,
    runtime_overrides = "absent",
    desktop_bootstrap_transport = "private-ssh-checksum-verified",
  },
  probes = {
    aspen_native = "verified",
    desktop_native = "verified",
    https = "verified",
    unknown_rid = "rejected",
    receive_pack = "rejected",
    wrong_service = "rejected",
    missing_object = "rejected",
  },
  authority_boundary = {
    seed_credentials = ["machine-scoped-radicle-node-key"],
    delegate_credentials_absent = true,
    protect_home = true,
    no_new_privileges = true,
    capability_bounding_set_empty = true,
  },
  evidence = [
    "cairn/archive/2026-07-27-admit-durable-file-publication-radicle-source/evidence/declarative-deployment-2026-07-27.md",
    "durable-file-publication:cairn/archive/2026-07-27-establish-durable-file-publication/evidence/validation.md",
  ],
  non_claims = [
    "library-correctness",
    "consumer-correctness",
    "release-readiness",
    "seed-delegate-authority",
    "automatic-https-failover",
    "radicle-only-replica-bootstrap",
    "permanent-network-availability",
    "retention-or-deletion-authority",
  ],
}
in
receipt
