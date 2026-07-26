# Typed evidence for the bounded private Radicle repository pilot.
let PrivatePilotReceipt = {
  schema_version | Number,
  receipt_type | String,
  status | String,
  observed_date | String,
  policy
    | {
      implementation_revision | String,
      public_rids | Array String,
      private_rids | Array String,
      https_rids | Array String,
      ci_rids | Array String,
      signed_refs_feature | String,
    },
  publication
    | {
      rid | String,
      visibility | String,
      reviewed_commit | String,
      source_archive_blake3 | String,
      identity_revision | String,
      identity_root | String,
      identity_blake3 | String,
      delegate | String,
      approval_threshold | Number,
      delegate_sigrefs | String,
      allowed_peers | Array String,
      denied_peer | String,
      non_secret_fixture | Bool,
    },
  primary
    | {
      host | String,
      node_id | String,
      node_fingerprint | String,
      system_closure | String,
      reconciled_repository_count | Number,
      identity_revision | String,
      delegate_sigrefs | String,
      commit | String,
      source_archive_blake3 | String,
    },
  replica
    | {
      host | String,
      node_id | String,
      node_fingerprint | String,
      system_closure | String,
      reconciled_repository_count | Number,
      identity_revision | String,
      delegate_sigrefs | String,
      commit | String,
      source_archive_blake3 | String,
    },
  authorized_acquisitions
    | Array {
      seed_node_id | String,
      client_did | String,
      fresh_profile | Bool,
      direct_seed_only | Bool,
      commit | String,
      source_archive_blake3 | String,
    },
  denied_acquisitions
    | Array {
      seed_node_id | String,
      client_did | String,
      fresh_profile | Bool,
      inventory_private_rid_absent | Bool,
      clone_rejected | Bool,
      checkout_absent | Bool,
    },
  https
    | {
      private_upload_pack_status | Number,
      private_receive_pack_status | Number,
      public_upload_pack_status | Number,
    },
  backup
    | {
      encrypted | Bool,
      source_failure_domain | String,
      target_failure_domain | String,
      archive | String,
      state_manifest_blake3 | String,
      state_records | Number,
      state_bytes | Number,
      recovery_manifest_blake3 | String,
      recovery_records | Number,
      recovery_bytes | Number,
    },
  recovery
    | {
      result | String,
      repository_count | Number,
      node_id | String,
      node_fingerprint | String,
      private_commit | String,
      private_identity_revision | String,
      private_sigrefs | String,
      private_source_blake3 | String,
      cleanup_verified | Bool,
    },
  authority_boundary
    | {
      seed_allowed_credentials | Array String,
      seed_forbidden_authorities_absent | Bool,
      desktop_native_only | Bool,
      private_https_absent | Bool,
      private_ci_absent | Bool,
      runtime_override_removed | Bool,
    },
  non_claims | Array String,
  evidence | Array String,
}
in
let receipt_schema_version = 1 in
let native_repository_count = 4 in
let state_record_count = 303242 in
let state_byte_count = 57970684391 in
let recovery_record_count = 6 in
let recovery_byte_count = 72363700 in
let restored_repository_count = 6763 in
let http_ok = 200 in
let http_not_found = 404 in
let approval_threshold_value = 1 in
let bounded_exec_rid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo" in
let artifact_auth_rid = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f" in
let execution_graph_rid = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a" in
let private_rid = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg" in
let private_commit_value = "ff4ff027817465b1bb04251a8a98db42cc610b0c" in
let private_source_blake3_value = "514904bdcf5f23b0813c567efbc8b6732248de94482037a58011bfff3fc26853" in
let private_identity_revision_value = "7fe3c9bd6a2d01a8317acb44ba386988375898da" in
let private_identity_root = "bf5e168201192881cf34e9ff7f7c39ee42dc7d62" in
let private_identity_blake3 = "a080d88d7b9cd58bf08130308c487b968863191caafea7f7f0e973471a2ed3b2" in
let private_sigrefs_value = "fc566eae3a5954df30d9499e0f85fe1b45a34d46" in
let author_did = "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx" in
let aspen_node_id = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8" in
let aspen_did = "did:key:%{aspen_node_id}" in
let desktop_node_id = "z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG" in
let desktop_did = "did:key:%{desktop_node_id}" in
let authorized_client_did = "did:key:z6MkwGV7ypRii8RjoSotmUbuKU4MwGQf3iw8AdhuJkkyD4wd" in
let denied_client_did = "did:key:z6MksVCc4QAvmZrZXX2MWoGwo9XqDUbiFjsjDZuRZrbgEu6h" in
let public_rids_value = [bounded_exec_rid, artifact_auth_rid, execution_graph_rid] in
let receipt | PrivatePilotReceipt = {
  schema_version = receipt_schema_version,
  receipt_type = "onix.radicle-private-pilot.v1",
  status = "accepted",
  observed_date = "2026-07-25",
  policy = {
    implementation_revision = "956cc432ad990c346326718d3a94c512e9020427",
    public_rids = public_rids_value,
    private_rids = [private_rid],
    https_rids = public_rids_value,
    ci_rids = [bounded_exec_rid],
    signed_refs_feature = "parent",
  },
  publication = {
    rid = private_rid,
    visibility = "private",
    reviewed_commit = private_commit_value,
    source_archive_blake3 = private_source_blake3_value,
    identity_revision = private_identity_revision_value,
    identity_root = private_identity_root,
    identity_blake3 = private_identity_blake3,
    delegate = author_did,
    approval_threshold = approval_threshold_value,
    delegate_sigrefs = private_sigrefs_value,
    allowed_peers = [aspen_did, desktop_did, authorized_client_did],
    denied_peer = denied_client_did,
    non_secret_fixture = true,
  },
  primary = {
    host = "aspen1",
    node_id = aspen_node_id,
    node_fingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE",
    system_closure = "/nix/store/kjsrz3h86rk6503wk3xdq1rq3wckh8ly-nixos-system-aspen1-26.11.20260629.7a1a647",
    reconciled_repository_count = native_repository_count,
    identity_revision = private_identity_revision_value,
    delegate_sigrefs = private_sigrefs_value,
    commit = private_commit_value,
    source_archive_blake3 = private_source_blake3_value,
  },
  replica = {
    host = "britton-desktop",
    node_id = desktop_node_id,
    node_fingerprint = "SHA256:JHQTPqoMr4kLqBsrAPSRNXUuzETiHAoiKBM/VWftmEg",
    system_closure = "/nix/store/lvsf8gfpcbg4h6psk283n41x1vc0r4iq-nixos-system-britton-desktop-26.11.20260629.7a1a647",
    reconciled_repository_count = native_repository_count,
    identity_revision = private_identity_revision_value,
    delegate_sigrefs = private_sigrefs_value,
    commit = private_commit_value,
    source_archive_blake3 = private_source_blake3_value,
  },
  authorized_acquisitions = [
    {
      seed_node_id = aspen_node_id,
      client_did = authorized_client_did,
      fresh_profile = true,
      direct_seed_only = true,
      commit = private_commit_value,
      source_archive_blake3 = private_source_blake3_value,
    },
    {
      seed_node_id = desktop_node_id,
      client_did = authorized_client_did,
      fresh_profile = true,
      direct_seed_only = true,
      commit = private_commit_value,
      source_archive_blake3 = private_source_blake3_value,
    },
  ],
  denied_acquisitions = [
    {
      seed_node_id = aspen_node_id,
      client_did = denied_client_did,
      fresh_profile = true,
      inventory_private_rid_absent = true,
      clone_rejected = true,
      checkout_absent = true,
    },
    {
      seed_node_id = desktop_node_id,
      client_did = denied_client_did,
      fresh_profile = true,
      inventory_private_rid_absent = true,
      clone_rejected = true,
      checkout_absent = true,
    },
  ],
  https = {
    private_upload_pack_status = http_not_found,
    private_receive_pack_status = http_not_found,
    public_upload_pack_status = http_ok,
  },
  backup = {
    encrypted = true,
    source_failure_domain = "aspen-primary-site",
    target_failure_domain = "britton-desktop-workstation",
    archive = "aspen1-britton-desktop-2026-07-25T22:22:31",
    state_manifest_blake3 = "915134d3d2245cf6b823558fa32abc04c04346ee05c635eae28600f78920bff1",
    state_records = state_record_count,
    state_bytes = state_byte_count,
    recovery_manifest_blake3 = "f07e19303e8880b01b2baac97cf11f2f207030fdbe64224d6d26e6a940e3dddd",
    recovery_records = recovery_record_count,
    recovery_bytes = recovery_byte_count,
  },
  recovery = {
    result = "verified",
    repository_count = restored_repository_count,
    node_id = aspen_node_id,
    node_fingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE",
    private_commit = private_commit_value,
    private_identity_revision = private_identity_revision_value,
    private_sigrefs = private_sigrefs_value,
    private_source_blake3 = private_source_blake3_value,
    cleanup_verified = true,
  },
  authority_boundary = {
    seed_allowed_credentials = ["machine-scoped-radicle-node-key"],
    seed_forbidden_authorities_absent = true,
    desktop_native_only = true,
    private_https_absent = true,
    private_ci_absent = true,
    runtime_override_removed = true,
  },
  non_claims = [
    "production-secret-confidentiality",
    "global-metadata-secrecy",
    "traffic-analysis-resistance",
    "anonymity",
    "multi-delegate-private-governance",
    "secure-deletion",
    "automatic-failover",
    "geographic-independence",
    "source-correctness",
    "protocol-enforced-ci",
    "release-readiness",
    "whole-fleet-migration-readiness",
  ],
  evidence = [
    "cairn/changes/pilot-private-radicle-source/evidence/private-publication-and-recovery-2026-07-25.md",
    "docs/radicle-private-pilot.md",
    "evidence/radicle/private-pilot-v1.json",
  ],
}
in
receipt
