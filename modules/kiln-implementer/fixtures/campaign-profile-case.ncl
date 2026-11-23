# Exercise the constructor's exported input contract without mocking owner contracts.
let { Inputs, .. } = import "../campaign-profile.ncl" in
let digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" in
let external_ref = {
  contract_version = 1,
  provider_namespace = "cairn",
  native_kind = "git_commit",
  native_id = "abc123",
}
in
fun routes =>
  {
    campaign_id = "fixture-campaign",
    campaign_database = "/var/lib/campaign.sqlite",
    implementation_database = "/var/lib/implementation.sqlite",
    verification_routes = routes,
    verifier_authority = "/etc/ci/authority.json",
    bound_input_directory = "/var/lib/ci/bound",
    candidate_export_directory = "/var/lib/ci/export",
    worker = { dispatch_plan = "/etc/ci/plan.json", request = "/etc/ci/request.json" },
    native_cairn = {
      repository_root = "/var/lib/ci/source",
      source = external_ref,
      implementation_policy = {
        repository = "owner/repository",
        project = "fixture",
        base = external_ref,
        actor = "fixture",
        requested_outcome = "verify routes",
        acceptance = [],
        permitted_paths = [],
        permitted_effects = [],
        verification_profile = digest,
        budget = { attempts = 1, minutes_per_attempt = 1 },
        terminal_policy = "fixture",
        priority = 1,
      },
    },
    delivery = {
      route = "github_pull_request",
      github = {
        enrollment = "/etc/ci/enrollment.json",
        remote_profile = "/etc/ci/remote.json",
        publication_policy = { base_branch = "main", title = "fixture", body = "" },
        landing_policy = { required_checks = [], required_approvals = 0 },
        lifecycle_action = "observe_reviewed_sync",
        lifecycle_receipt_template = "receipt.json",
        repository = "/var/lib/ci/repository",
        authoritative_report_directory = "/var/lib/ci/reports",
        timeout_ms = 1000,
      },
      native_git = null,
    },
    claim_lease_ms = 1000,
    maximum_operations = 1,
    workspace = {
      repository = "owner/repository",
      repository_path = "/var/lib/ci/source",
      work_root = "/var/lib/ci/work",
      max_entries = 1,
      max_path_bytes = 1,
      max_file_bytes = 1,
      max_total_bytes = 1,
    },
  } | Inputs
