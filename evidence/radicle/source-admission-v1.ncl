# Typed evidence for exact two-source Radicle admission.
let SourceAdmissionReceipt = {
  schema_version | Number,
  receipt_type | String,
  status | String,
  observed_date | String,
  policy
    | {
      source_revision | String,
      signed_refs_feature | String,
      repositories | Array { name | String, rid | String, reviewed_commit | String, source_archive_blake3 | String },
      ci_rids | Array String,
    },
  publication
    | {
      repository | String,
      revision | String,
      receipt_type | String,
      receipt_blake3 | String,
      status | String,
    },
  governance
    | {
      identity_revision | String,
      identity_root | String,
      delegates | Array String,
      approval_threshold | Number,
      signed_main_delegates | Array String,
      offline_delegate | String,
      public_bundle_blake3 | String,
    },
  primary
    | {
      host | String,
      node_id | String,
      node_fingerprint | String,
      system_closure | String,
      reconciled_repository_count | Number,
      client_nid | String,
      commit | String,
      source_archive_blake3 | String,
      undeclared_rid | String,
      isolated_egress | String,
      storage_access | String,
      secret_access | String,
    },
  replica
    | {
      host | String,
      node_id | String,
      node_fingerprint | String,
      system_closure | String,
      reconciled_repository_count | Number,
      client_nid | String,
      commit | String,
      source_archive_blake3 | String,
      undeclared_rid | String,
      isolated_egress | String,
      storage_access | String,
      secret_access | String,
    },
  https
    | {
      url | String,
      commit | String,
      source_archive_blake3 | String,
      unknown_rid_status | Number,
      receive_pack_status | Number,
      root_status | Number,
      public_origin_count | Number,
    },
  authority_boundary
    | {
      seed_allowed_credentials | Array String,
      seed_forbidden_authorities_absent | Bool,
      ci_rids | Array String,
      artifact_auth_ci_enabled | Bool,
      desktop_native_only | Bool,
    },
  non_claims | Array String,
  evidence | Array String,
}
in
let repository_count = 2 in
let delegate_threshold = 2 in
let expected_public_origin_count = 1 in
let http_not_found = 404 in
let bounded_exec_rid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo" in
let artifact_auth_rid = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f" in
let artifact_auth_commit = "799459346d5416fbd7b9f55840a7371441b55afa" in
let artifact_auth_blake3 = "246a7cad91e7e8a158e22da21f3bff3e61aa0431a58936b5a739178bc62064c7" in
let author_delegate = "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx" in
let bonsai_delegate = "did:key:z6MkjCqx5ksRqcDeNeuEnz53udbUHebRLHhddCxecWJu9koE" in
let pine_delegate = "did:key:z6MkmkA6sEzzMffaWqKEKJcDh8LjAzgrJLrTNi971KN3X6sh" in
let receipt | SourceAdmissionReceipt = {
  schema_version = 1,
  receipt_type = "onix.radicle-source-admission.v1",
  status = "accepted",
  observed_date = "2026-07-25",
  policy = {
    source_revision = "a3f5a18b36a0c874c1fce0d47acee19932f4d931",
    signed_refs_feature = "parent",
    repositories = [
      {
        name = "bounded-exec",
        rid = bounded_exec_rid,
        reviewed_commit = "29dac88ecded94457572db3fdfaaaab95fa91525",
        source_archive_blake3 = "4fbbf8f0749262469f00748e04c775180488dba800303f139172656d25931927",
      },
      {
        name = "artifact-auth",
        rid = artifact_auth_rid,
        reviewed_commit = artifact_auth_commit,
        source_archive_blake3 = artifact_auth_blake3,
      },
    ],
    ci_rids = [bounded_exec_rid],
  },
  publication = {
    repository = "artifact-auth",
    revision = "e41340bec587b6d049b5cc518ec7db925dde84be",
    receipt_type = "artifact-auth.radicle-publication.v1",
    receipt_blake3 = "e58a3de4d6b3b32a547c3cfe5c3e829292cda73891c7776f214f5d4edce10b1c",
    status = "accepted",
  },
  governance = {
    identity_revision = "c22900ae6b7b5637aa0e378fe00503cf02c6d1bf",
    identity_root = "e95f12e9791861f072e9a60f7d0d75f08428d721",
    delegates = [author_delegate, bonsai_delegate, pine_delegate],
    approval_threshold = delegate_threshold,
    signed_main_delegates = [author_delegate, bonsai_delegate],
    offline_delegate = pine_delegate,
    public_bundle_blake3 = "7f96561a705151266e83641bdc53cf692518f0e5507f10acc3074c45d6ebca5f",
  },
  primary = {
    host = "aspen1",
    node_id = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8",
    node_fingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE",
    system_closure = "/nix/store/0j4sb2mnmmy6skiy89hy83p9lsn6rdwq-nixos-system-aspen1-26.11.20260629.7a1a647",
    reconciled_repository_count = repository_count,
    client_nid = "z6MkkQEGLf4NPLDzwguTX7LWQYxQvWnbjFvh2mECYHzuPPvb",
    commit = artifact_auth_commit,
    source_archive_blake3 = artifact_auth_blake3,
    undeclared_rid = "rejected",
    isolated_egress = "blocked",
    storage_access = "blocked",
    secret_access = "blocked",
  },
  replica = {
    host = "britton-desktop",
    node_id = "z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG",
    node_fingerprint = "SHA256:JHQTPqoMr4kLqBsrAPSRNXUuzETiHAoiKBM/VWftmEg",
    system_closure = "/nix/store/a2md0l6n2g56xcg44v93xalyc6zcaxp1-nixos-system-britton-desktop-26.11.20260629.7a1a647",
    reconciled_repository_count = repository_count,
    client_nid = "z6Mku6MfTxgiBW2gtDpAJqk6Cf6FStVbNx4JrcyDjb9bUTqQ",
    commit = artifact_auth_commit,
    source_archive_blake3 = artifact_auth_blake3,
    undeclared_rid = "rejected",
    isolated_egress = "blocked",
    storage_access = "blocked",
    secret_access = "blocked",
  },
  https = {
    url = "https://git.onix.computer/z4JGYYW7WsesXUq7MXVdx16Fawu2f.git",
    commit = artifact_auth_commit,
    source_archive_blake3 = artifact_auth_blake3,
    unknown_rid_status = http_not_found,
    receive_pack_status = http_not_found,
    root_status = http_not_found,
    public_origin_count = expected_public_origin_count,
  },
  authority_boundary = {
    seed_allowed_credentials = ["machine-scoped-radicle-node-key"],
    seed_forbidden_authorities_absent = true,
    ci_rids = [bounded_exec_rid],
    artifact_auth_ci_enabled = false,
    desktop_native_only = true,
  },
  non_claims = [
    "artifact-auth-source-correctness",
    "valence-behavior-correctness",
    "live-delegate-replacement",
    "third-delegate-live-convergence",
    "private-repository-confidentiality",
    "automatic-https-failover",
    "geographic-or-building-power-independence",
    "protocol-enforced-mandatory-ci",
    "release-readiness",
    "whole-stack-github-independence",
  ],
  evidence = [
    "cairn/archive/2026-07-25-admit-artifact-auth-radicle-source/evidence/deployment-and-probes-2026-07-25.md",
    "evidence/radicle/source-admission-v1.json",
    "artifact-auth:evidence/radicle/publication-v1.json",
    "valence:evidence/radicle/artifact-auth-cutover-v1.json",
  ],
}
in
receipt
