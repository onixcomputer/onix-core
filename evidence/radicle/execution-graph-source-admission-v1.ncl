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
      publication_revision | String,
      publication_receipt_blake3 | String,
    },
  governance
    | {
      identity_revision | String,
      delegates | Array String,
      threshold | Number,
      signed_refs_feature | String,
      author_sigrefs | String,
      bonsai_sigrefs | String,
      pine_sigrefs | String,
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
    },
  probes
    | {
      aspen_native | String,
      desktop_native | String,
      https | String,
      aspen_only | String,
      desktop_only | String,
      unknown_rid | String,
      receive_pack | String,
      wrong_service | String,
      missing_object | String,
    },
  evidence | Array String,
  non_claims | Array String,
}
in
let canonical_threshold = 2 in
let expected_native_desired_count = 4 in
let expected_public_https_count = 3 in
let bounded_exec = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo" in
let artifact_auth = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f" in
let execution_graph = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a" in
let private_fixture = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg" in
let receipt | Receipt = {
  schema_version = 1,
  receipt_type = "onix.radicle-execution-graph-source-admission.v1",
  status = "accepted",
  observed_date = "2026-07-26",
  repository = {
    rid = execution_graph,
    reviewed_commit = "03736f1ec46c377ff86b451260ad68aa70ff3b0b",
    source_archive_blake3 = "4b5aa3756369236fc82fbbf501d35993cfa208f142694cdd30ca370d6241192c",
    publication_revision = "fffc6968f6e1",
    publication_receipt_blake3 = "5573a000f71f1992ed3aa6ddb1197aca29b2b551ef58643b5bd930bef78270cf",
  },
  governance = {
    identity_revision = "d407356b5fd5465c62aca4d7d6c61156947cbac1",
    delegates = [
      "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx",
      "did:key:z6MkjCqx5ksRqcDeNeuEnz53udbUHebRLHhddCxecWJu9koE",
      "did:key:z6MkmkA6sEzzMffaWqKEKJcDh8LjAzgrJLrTNi971KN3X6sh",
    ],
    threshold = canonical_threshold,
    signed_refs_feature = "parent",
    author_sigrefs = "bd0d800f32dfdf32e76ea55ceb87e346cc801eb9",
    bonsai_sigrefs = "9bd0ff3eaf86ace7a1fca969a9107dc014171d8b",
    pine_sigrefs = "50b6d7658056215317212248da17774800547164",
  },
  policy = {
    implementation_revision = "956cc432ad990c346326718d3a94c512e9020427",
    public_rids = [bounded_exec, artifact_auth, execution_graph],
    private_rids = [private_fixture],
    https_rids = [bounded_exec, artifact_auth, execution_graph],
    ci_rids = [bounded_exec],
  },
  deployment = {
    aspen_closure = "/nix/store/kjsrz3h86rk6503wk3xdq1rq3wckh8ly-nixos-system-aspen1-26.11.20260629.7a1a647",
    desktop_closure = "/nix/store/ka4bn1i15a5izsjh6jpqzy1mxpqsq54s-nixos-system-britton-desktop-26.11.20260629.7a1a647",
    native_desired_count = expected_native_desired_count,
    public_https_count = expected_public_https_count,
    runtime_overrides = "absent",
  },
  probes = {
    aspen_native = "verified",
    desktop_native = "verified",
    https = "verified",
    aspen_only = "verified",
    desktop_only = "verified",
    unknown_rid = "rejected",
    receive_pack = "rejected",
    wrong_service = "rejected",
    missing_object = "rejected",
  },
  evidence = [
    "cairn/changes/admit-execution-graph-radicle-source/evidence/declarative-deployment-2026-07-25.md",
    "execution-graph:evidence/radicle/publication-v1.json",
  ],
  non_claims = [
    "graph-correctness",
    "consumer-correctness",
    "release-readiness",
    "seed-delegate-authority",
    "automatic-https-failover",
    "whole-stack-github-independence",
  ],
}
in
receipt
