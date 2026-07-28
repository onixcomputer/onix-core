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
      source_archive_bytes | Number,
      release_bundle_blake3 | String,
      candidate_blake3 | String,
      license | String,
      https_url | String,
    },
  producer
    | {
      identity_revision | String,
      delegates | Array String,
      threshold | Number,
      signed_refs_feature | String,
      author_sigrefs | String,
      publication_authority | String,
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
      native_public_count | Number,
      public_https_count | Number,
      runtime_overrides | String,
    },
  probes
    | {
      aspen_native | String,
      desktop_native | String,
      independent_replica | String,
      https | String,
      archive | String,
      git_fsck | String,
      unknown_rid | String,
      receive_pack | String,
      wrong_service | String,
      endpoint_root | String,
    },
  evidence | Array String,
  non_claims | Array String,
}
in
let bounded_exec = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo" in
let artifact_auth = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f" in
let execution_graph = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a" in
let choregraph = "rad:zL2ncTUeASVYwcoGkEXv9JKgGbAF" in
let private_fixture = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg" in
let receipt | Receipt = {
  schema_version = 1,
  receipt_type = "onix.radicle-choregraph-source-admission.v1",
  status = "accepted",
  observed_date = "2026-07-27",
  repository = {
    rid = choregraph,
    reviewed_commit = "fc47c5f4ecbb7b4341af690fa42199f25d57f54c",
    source_archive_blake3 = "dcb1faf95a7487145496ce986ae1639908600ace5bd77c4d96a37a530a7538a5",
    source_archive_bytes = 1781760,
    release_bundle_blake3 = "a2ac1336679542fa9573b356daddc18266fdda8147ddbe28f85aa37d135030d9",
    candidate_blake3 = "e4b5cd7bd77d78c20cf8b96cd0c038144028d2287000757c8ab68f5f5dfdff1a",
    license = "AGPL-3.0-or-later",
    https_url = "https://git.onix.computer/zL2ncTUeASVYwcoGkEXv9JKgGbAF.git",
  },
  producer = {
    identity_revision = "fce6d85cbe015b49ddab43db66884f550e66153e",
    delegates = ["did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx"],
    threshold = 1,
    signed_refs_feature = "parent",
    author_sigrefs = "70148d3d6d0f5d5995fc7c4b78002189701748b5",
    publication_authority = "operator-authorized",
  },
  policy = {
    implementation_revision = "1a6446874d7bbe83f01bad13e9855f85423dd7e6",
    public_rids = [bounded_exec, artifact_auth, execution_graph, choregraph],
    private_rids = [private_fixture],
    https_rids = [bounded_exec, artifact_auth, execution_graph, choregraph],
    ci_rids = [bounded_exec],
  },
  deployment = {
    aspen_closure = "/nix/store/ia697wglrzfc40hx6qv1sz18sv2d4w4m-nixos-system-aspen1-26.11.20260629.7a1a647",
    desktop_closure = "/nix/store/2wdnwhb1pbg4pix0hyzmk0gbafcq4f3l-nixos-system-britton-desktop-26.11.20260629.7a1a647",
    native_public_count = 4,
    public_https_count = 4,
    runtime_overrides = "absent",
  },
  probes = {
    aspen_native = "verified",
    desktop_native = "verified",
    independent_replica = "paintedlife-verified",
    https = "verified",
    archive = "verified",
    git_fsck = "verified",
    unknown_rid = "rejected-404",
    receive_pack = "rejected-404",
    wrong_service = "rejected-404",
    endpoint_root = "rejected-404",
  },
  evidence = [
    "cairn/changes/admit-choregraph-radicle-source/evidence/deployment-and-probes-2026-07-27.md",
    "choregraph:evidence/release/publication-candidate.ncl",
  ],
  non_claims = [
    "choregraph-correctness",
    "consumer-correctness",
    "release-eligibility",
    "seed-delegate-authority",
    "indefinite-availability",
    "whole-stack-correctness",
  ],
}
in
receipt
