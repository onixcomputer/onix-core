# Canonical typed source for the accepted Aspen1 Radicle bootstrap receipt.
# Export with: nickel export --format json evidence/radicle/bootstrap-v1.ncl
let Receipt = {
  schema_version | Number,
  receipt_type | String,
  status | String,
  observed_date | String,
  policy
    | {
      source_revision | String,
      minimum_node_version | String,
      minimum_signed_refs_feature | String,
      check | String,
    },
  packages
    | {
      node | { version | String, store_path | String },
      httpd | { version | String, store_path | String },
    },
  machine
    | {
      host | String,
      deployment_target | String,
      failure_domain | String,
      system_closure | String,
    },
  identity
    | {
      node_id | String,
      ssh_fingerprint | String,
      continuity | String,
    },
  repositories
    | Array {
      rid | String,
      visibility | String,
      expected_commit | String,
      observed_commit | String,
      source_archive_blake3 | String,
    },
  endpoints
    | {
      native
        | {
          address | String,
          firewall_interface | String,
          wildcard_listener | Bool,
        },
      httpd | { address | String, publicly_routable | Bool },
      https_git
        | {
          url | String,
          tls_termination | String,
          origin | String,
          upload_pack_only | Bool,
        },
    },
  acquisition
    | {
      native
        | {
          result | String,
          client_boundary | String,
          signed_refs_feature | String,
          commit | String,
        },
      https_git
        | {
          result | String,
          commit | String,
          source_archive_blake3 | String,
        },
    },
  rejection_probes
    | {
      native_undeclared_rid | String,
      https_undeclared_rid_status | Number,
      https_receive_pack_status | Number,
      https_api_status | Number,
      https_root_status | Number,
      https_missing_revision | String,
      https_write | String,
    },
  services
    | {
      node | String,
      httpd | String,
      policy_timer | String,
      nginx | String,
      cloudflare_tunnel | String,
      backup_timer | String,
      restart_continuity | String,
      reconciled_repository_count | Number,
    },
  monitoring
    | {
      systemd_exporter | String,
      node_alert | String,
      httpd_alert | String,
      policy_alert | String,
    },
  authority_boundary
    | {
      service_role | String,
      allowed_credentials | Array String,
      forbidden_authorities | Array String,
      host_secrets_masked | Bool,
      home_protected | Bool,
      capability_bounding_set_empty | Bool,
    },
  recovery
    | {
      result | String,
      target_host | String,
      target_failure_domain | String,
      repository_id | String,
      encryption | String,
      accepted_archive | String,
      state_manifest_blake3 | String,
      state_record_count | Number,
      state_bytes | Number,
      recovery_input_manifest_blake3 | String,
      recovery_input_record_count | Number,
      recovery_input_bytes | Number,
      restored_node_id | String,
      restored_fingerprint | String,
      restored_repository_count | Number,
      plaintext_cleanup | String,
    },
  non_claims | Array String,
  evidence | Array String,
}
in
let receipt | Receipt = {
  schema_version = 1,
  receipt_type = "onix.radicle.bootstrap.v1",
  status = "accepted",
  observed_date = "2026-07-25",
  policy = {
    source_revision = "2b104f11",
    minimum_node_version = "1.9.1",
    minimum_signed_refs_feature = "parent",
    check = "checks.x86_64-linux.radicle-node-policy",
  },
  packages = {
    node = {
      version = "1.9.1",
      store_path = "/nix/store/r2hjw60rdpb3faxa6xglywxl77rx9ql2-radicle-node-1.9.1",
    },
    httpd = {
      version = "0.25.0",
      store_path = "/nix/store/zjnwy6nnilq6f4jnsm1h4wjiapwi36va-radicle-httpd-0.25.0",
    },
  },
  machine = {
    host = "aspen1",
    deployment_target = "root@aspen1.local",
    failure_domain = "aspen-primary-site",
    system_closure = "/nix/store/mn97i50mk7damrfih2k76ih5f6mz8nxw-nixos-system-aspen1-26.11.20260629.7a1a647",
  },
  identity = {
    node_id = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8",
    ssh_fingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE",
    continuity = "recovered-and-pinned",
  },
  repositories = [
    {
      rid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo",
      visibility = "public",
      expected_commit = "29dac88ecded94457572db3fdfaaaab95fa91525",
      observed_commit = "29dac88ecded94457572db3fdfaaaab95fa91525",
      source_archive_blake3 = "4fbbf8f0749262469f00748e04c775180488dba800303f139172656d25931927",
    }
  ],
  endpoints = {
    native = {
      address = "100.100.103.95:8776",
      firewall_interface = "tailscale0",
      wildcard_listener = false,
    },
    httpd = {
      address = "127.0.0.1:8080",
      publicly_routable = false,
    },
    https_git = {
      url = "https://git.onix.computer/z2CpqLFpdP36fZXYUK5ZNWxMibpCo.git",
      tls_termination = "cloudflare-tunnel",
      origin = "127.0.0.1:8081",
      upload_pack_only = true,
    },
  },
  acquisition = {
    native = {
      result = "verified",
      client_boundary = "dynamic-user-aspen-only-egress",
      signed_refs_feature = "parent",
      commit = "29dac88ecded94457572db3fdfaaaab95fa91525",
    },
    https_git = {
      result = "verified",
      commit = "29dac88ecded94457572db3fdfaaaab95fa91525",
      source_archive_blake3 = "4fbbf8f0749262469f00748e04c775180488dba800303f139172656d25931927",
    },
  },
  rejection_probes = {
    native_undeclared_rid = "rejected",
    https_undeclared_rid_status = 404,
    https_receive_pack_status = 404,
    https_api_status = 404,
    https_root_status = 404,
    https_missing_revision = "rejected",
    https_write = "rejected",
  },
  services = {
    node = "active",
    httpd = "active",
    policy_timer = "active",
    nginx = "active",
    cloudflare_tunnel = "active",
    backup_timer = "active",
    restart_continuity = "verified",
    reconciled_repository_count = 1,
  },
  monitoring = {
    systemd_exporter = "verified",
    node_alert = "loaded",
    httpd_alert = "loaded",
    policy_alert = "loaded-and-clear",
  },
  authority_boundary = {
    service_role = "replication-and-read-only-transport",
    allowed_credentials = ["machine-scoped-radicle-node-key"],
    forbidden_authorities = [
      "repository-delegate",
      "canonical-ref",
      "ci",
      "deployment",
      "release-signing",
      "cache-write",
      "artifact-administration",
      "cloudflare",
      "github",
      "buildbot",
      "nix-signing",
      "vaultwarden",
      "matrix",
    ],
    host_secrets_masked = true,
    home_protected = true,
    capability_bounding_set_empty = true,
  },
  recovery = {
    result = "verified",
    target_host = "britton-desktop",
    target_failure_domain = "britton-desktop-workstation",
    repository_id = "8d87c9acca56a9dfac56f152c98bd5dec748260ca5d7ba4bfe9fba95c1916921",
    encryption = "borg-repokey",
    accepted_archive = "aspen1-britton-desktop-2026-07-24T20:48:20",
    state_manifest_blake3 = "480aa43cba75d5b1176b65df9a0f69c4a11ba8b36b426210914bc45ccdcadde0",
    state_record_count = 303134,
    state_bytes = 57970493900,
    recovery_input_manifest_blake3 = "f24d9e0a56109ae71570e8b8c4116448e340053380f72dd5f91d25ff071d2610",
    recovery_input_record_count = 6,
    recovery_input_bytes = 72341285,
    restored_node_id = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8",
    restored_fingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE",
    restored_repository_count = 6760,
    plaintext_cleanup = "verified",
  },
  non_claims = [
    "independent-seed-availability",
    "single-seed-outage-survival",
    "private-repository-confidentiality",
    "repository-source-correctness",
    "patch-review-correctness",
    "ci-isolation-beyond-observed-service-boundary",
    "canonical-ref-enforcement",
    "release-readiness",
    "whole-stack-github-independence",
    "geographic-or-building-power-independence",
  ],
  evidence = [
    "cairn/changes/bootstrap-radicle-forge-node/evidence/aspen1-live-bootstrap-2026-07-24.md",
    "docs/radicle-forge-bootstrap.md",
  ],
}
in
receipt
