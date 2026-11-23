# Human-reviewed live verified-PR pilot configuration for one sandbox issue.
# Exported field by field by build_pilot.py; no credential is a field here.
let Digest = std.contract.from_predicate (fun value =>
  std.is_string value && std.string.is_match "^[0-9a-f]{64}$" value
) in
let Program = { path | String, blake3 | Digest } in
let runtime = fun selector => { runtime = selector } in
let zero = std.string.join "" (std.array.replicate 64 "0") in
fun raw =>
let input = raw | {
  seed_identity | Digest,
  verification_identity | Digest,
  output_contract_identity | Digest,
  remote_identity | Digest,
  # Kiln's kiln_core::types::ExternalRef, exactly (contract_version 1).
  base | { contract_version | std.contract.from_predicate (fun v => v == 1), provider_namespace | String, native_kind | String, native_id | String },
  git | Program,
  worker | Program,
  sandbox | Program,
  relay | Program,
  shell | Program,
  lattice | Program,
  cargo_check | Program,
  worker_revision | String,
  spec | {
    name | std.contract.from_predicate (fun value => value == "bug" || value == "feature"),
    case | { issue | Number, title | String, test | String, reproducer | Bool },
    model | { id | String, endpoint | String, upstream | { address | String, port | Number } },
    repository | { owner | String, name | String, id | Number, key | String, base | String, remote_url | String },
  },
} in
let root = "/var/lib/kiln-implementation" in
let spec = input.spec in
let repo = spec.repository in
let issue = "issue-%{std.to_string spec.case.issue}" in
let permitted = ["src/lib.rs"] in
let obligations_list = [
  { id = issue, statement = "`cargo test --features acceptance --test %{spec.case.test}` passes on the candidate with the acceptance test file pinned from base %{repo.base}" },
  { id = "ordinary-checks", statement = "`cargo test`, `cargo fmt --check` and `cargo clippy --all-targets -- -D warnings` stay green" },
] in
# Kiln admits only `build`, `review` and `test` check kinds.
let check = fun check_id check_kind obligations cargo_arguments => {
  id = check_id, kind = check_kind, program = input.cargo_check,
  arguments = ["%{check_id}.json"] @ cargo_arguments,
  prerequisites = [], acceptance = obligations,
  artifacts = ["%{check_id}.json"], timeout_ms = 120000,
} in
let worker_prompt =
  "Resolve GitHub issue #%{std.to_string spec.case.issue} in this Rust crate: \"%{spec.case.title}\". "
  ++ "The acceptance tests are in tests/%{spec.case.test}.rs and run with `cargo test --features acceptance --test %{spec.case.test}`. "
  ++ "Read src/lib.rs, Cargo.toml and that test file, then edit only src/lib.rs so the acceptance tests pass while `cargo test`, "
  ++ "`cargo fmt --check` and `cargo clippy --all-targets -- -D warnings` stay clean. Keep the code rustfmt-formatted. "
  ++ "Do not edit tests, Cargo.toml or Cargo.lock. You cannot run commands; reason from the sources. Reply done when finished."
in
let common = {
  project = repo.name,
  base = input.base,
  requested_outcome = "Resolve issue #%{std.to_string spec.case.issue}: %{spec.case.title}",
  acceptance = obligations_list,
  permitted_paths = permitted,
  permitted_effects = ["write_source"],
  verification_profile = input.verification_identity,
  budget = { attempts = 2, minutes_per_attempt = 20 },
  terminal_policy = "verified_pull_request",
  priority = 1,
} in
{
  verification = {
    schema = "kiln.verification-profile.v1",
    repository = repo.key,
    toolchain = input.seed_identity,
    environment_identity = input.seed_identity,
    environment = { LANG = "C.UTF-8", LC_ALL = "C.UTF-8" },
    checks = [
      check "acceptance" "test" [issue] ["test", "--locked", "--offline", "--features", "acceptance", "--test", spec.case.test],
      check "tests" "test" ["ordinary-checks"] ["test", "--locked", "--offline"],
      check "format" "review" ["ordinary-checks"] ["fmt", "--check"],
      check "clippy" "review" ["ordinary-checks"] ["clippy", "--locked", "--offline", "--all-targets", "--", "-D", "warnings"],
    ],
    # The bug's acceptance test fails on the base; the feature has no
    # baseline reproducer and needs explicit candidate acceptance.
    reproducer = if spec.case.reproducer then "acceptance" else null,
    # Pinned from the base: the candidate cannot weaken either acceptance
    # file, the feature gate or the lock.
    protected_paths = ["tests/word_count_whitespace.rs", "tests/char_frequency.rs", "Cargo.toml", "Cargo.lock"],
    allow_already_satisfied = false,
    cairn = null,
  },
  configuration = {
    "enrollment.json" = { repositories = [repo.key], actors = ["brittonr"] },
    "github-policy.json" = common & {
      repository = { owner = repo.owner, repository = repo.name, repository_id = repo.id, allow_fork_pull_requests = false },
      dependencies = [],
      # Admit only this guest's issue; every other open issue is unselected.
      selection = { issues = [spec.case.issue], labels = [] },
    },
    "worker-transport-profile.json" = {
      schema = "kiln.lattice-implementation-cli.v2",
      lattice_program = input.lattice.path, executable_blake3 = input.lattice.blake3,
      state_directory = "%{root}/lattice/implementation", output_directory = "%{root}/lattice/observations",
    },
  },
  runtime_template = {
    schema = "onix.kiln.runtime-template.v1",
    scope = "live-pilot",
    attempt_window_ms = 1200000,
    dispatch = {
      "attempt.json" = {
        schema = "lattice.implementation-attempt-run.v3",
        envelope = {
          schema = "lattice.implementation-attempt-envelope.v1",
          work_id = runtime "work", work_version = runtime "work_revision",
          source_kind = runtime "source_kind", source_id = runtime "source_id",
          repository = repo.key, base = runtime "base_oid", readiness_snapshot = runtime "readiness_snapshot",
          task_spec_digest = runtime "acceptance_digest", verification_profile = runtime "verification_profile",
          attempt_id = runtime "attempt", fence = runtime "fence", workspace_id = runtime "workspace",
          worker_profile = zero,
          budget = { max_turns = 40, max_seconds = 1080, max_cost_micros = 0 },
          policy_digest = zero,
        },
        admitted_envelope = "",
        expires_at_ms = runtime "expires_at_ms", workspace_root = runtime "workspace_root",
        read_paths = ["src", "tests", "Cargo.toml", "Cargo.lock", "README.md"],
        write_paths = permitted,
        # No network device: Lattice's host-side broker in the dispatcher's
        # model namespace is the worker's only route.
        network = false,
        program = input.worker.path, sandbox_program = input.sandbox.path,
        omp = {
          revision = input.worker_revision, executable_blake3 = input.worker.blake3,
          base_identity = zero, model = "lattice/%{spec.model.id}",
          prompt = worker_prompt,
          model_broker = {
            schema = "lattice.candidate-model-broker.v1",
            endpoint = spec.model.endpoint,
            model = spec.model.id,
            credential = { provider = "env", key = "KILN_IMPLEMENTATION_MODEL_KEY" },
            relay = input.relay, shell = input.shell,
            sandbox_blake3 = input.sandbox.blake3,
            expires_at_ms = runtime "expires_at_ms",
            max_requests = 64,
          },
        },
        worker_compute = { kind = "host_local" },
        execution_binding = {
          schema = "lattice.execution-binding.v1",
          compute = { kind = "host_local" },
          model_routes = { kind = "routes", routes = [{ name = "primary", route_identity = "blake3:%{zero}" }] },
        },
        output_limit_bytes = 4194304, allow_unchanged = false,
      },
      "dispatch-plan.json" = {
        schema = "kiln.implementation-dispatch-plan.v2",
        work_identity = runtime "work", work_revision = runtime "work_revision",
        attempt_identity = runtime "attempt", fence = runtime "fence", repository = repo.key,
        base = runtime "base",
        workspace = { identity = runtime "workspace", isolation = "isolated_snapshot", network = false, credentials = false },
        provider_profile = "onix-local-pilot-omp",
        permitted_paths = permitted, permitted_effects = ["write_source"],
        controls = { cancel = true, pause = false, resume = false },
        deadline_minutes = 20, token_budget = 2000000, invocation_budget = 64,
        expected_output = input.output_contract_identity,
      },
      "admission-observations.json" = [],
      "verification-profile.json" = { runtime = "verification_profile_document" },
      "verifier-authority.json" = {
        repository = repo.key, repository_root = "%{root}/verifier/repository",
        scratch_root = "%{root}/verifier/scratch", git = input.git, worker_uid = 931,
      },
    },
    live_execution = {
      needs = {
        work_version = "", task_family = "implementation",
        output_contract = input.output_contract_identity,
        definition = { source = "onix-core", id = "kiln-implementation-pilot-%{spec.name}" },
        profile_revision = runtime "worker_profile", policy_ref = "",
        harness = "omp", tools = ["read", "edit", "write"], sandbox = "isolated_snapshot",
        execution_backend = "native_lattice_local", model_backend = "openai_compatible_gateway",
        context_tokens = 131072,
        execution_resources = [{ unit = "worker_requests", amount = 1 }],
        modalities = ["text"], model_artifact = null,
        # Kiln's public tokens exclude "/" (kiln-core inventory.rs public_token).
        qualification_subject = "live-pilot", qualification_corpus = std.string.replace "/" ":" repo.key,
        qualification_protocol = "onix-local-pilot-omp-v1",
      },
      attempt_binding = {
        work_version = runtime "work", attempt = runtime "attempt", fence = runtime "fence",
        worker = { source = "onix-local-pilot", id = runtime "worker_profile" },
        execution_grant = { source = "onix-local-pilot", id = runtime "attempt" },
        model_services = [{ source = "onix-local-pilot", id = spec.model.id }],
        request_admissions = [{ source = "onix-local-pilot", id = runtime "route_identity" }],
      },
    },
    publication = {
      "publication.json" = {
        schema = "kiln.implementation-publication.v1",
        work_identity = runtime "work", work_revision = runtime "work_revision", attempt = runtime "attempt", fence = runtime "fence",
        handoff = runtime "handoff", verification = runtime "verification", repository = repo.key,
        base = runtime "base", base_branch = "main", candidate = runtime "candidate", tree = runtime "tree",
        branch = runtime "publication_branch",
        title = "Resolve #%{std.to_string spec.case.issue}: %{spec.case.title}",
        body = "Kiln implementation pilot candidate for #%{std.to_string spec.case.issue}, produced by the pinned OMP worker and independently verified (acceptance test pinned from base %{repo.base}, cargo test, fmt, clippy). Verified-PR delivery only: no automatic landing or merge.",
      },
      "publication-source-profile.json" = {
        schema = "kiln.github-publication-source.v1", repository_path = "%{root}/verifier/repository",
        remote = { remote_name = "origin", remote_url = repo.remote_url, transport = "https" },
        remote_identity = input.remote_identity, fixture = false,
      },
    },
  },
  # Input to Kiln's config/fair-admission-host-owner.ncl: this guest is one
  # registered host-local owner with one worker slot, a finite four-attempt
  # campaign, and exactly this repository and this guest's work class.
  host_owner_input = {
    provider = "onix-local-pilot-host",
    host = "kiln-pilot-%{spec.name}",
    generation = 1,
    capacity = { worker_slots = 1 },
    observation_ttl_ms = 600000,
    reservation_ttl_ms = 3600000,
    campaign = "implementer_pilot",
    tenant = "onix_local",
    deadline_ms = 1830297600000,
    quota = { worker_slots = 4 },
    per_work = { worker_slots = 1 },
    limits = {
      max_items = 8, max_bytes = 1048576, max_wait_ms = 86400000,
      max_observation_age_ms = 900000, max_retry_after_ms = 60000,
      max_children = 1, max_active = 1,
    },
    repositories = [{
      repository = repo.key,
      classes = [{
        name = if spec.name == "bug" then "bug" else "bounded-feature",
        project = repo.name,
        verification_profile = input.verification_identity,
      }],
    }],
  },
  ci_service_template = {
    schema = "kiln.web-service.v1", service_id = "kiln-implementation-pilot-ci",
    listen_address = "127.0.0.1:19443", origin = "https://localhost:19443",
    tls = { certificate_path = "/run/kiln-implementation-ci/cert.pem", private_key_path = "/run/kiln-implementation-ci/key.pem", min_version = "TLS1.3" },
    operator_token_file = "/run/kiln-implementation-ci/operator.token", worker_token_file = "/run/kiln-implementation-ci/worker.token",
    state_directory = "%{root}/canonical-ci",
    projects = [{
      id = repo.name, label = "Independent verification for the implementer sandbox pilot", repository_path = "%{root}/verifier/repository", reference = "refs/heads/main",
      source_limits = { max_entries = 4096, max_path_bytes = 4096, max_file_bytes = 4194304, max_total_bytes = 67108864 },
      workflow = {
        socket_path = "/run/kiln-implementation-ci/lattice.sock", allowed_user_ids = [933],
        transport_limits = { maximum_frame_bytes = 1048576, maximum_log_bytes = 65536, maximum_connections = 4, read_deadline_milliseconds = 1000, write_deadline_milliseconds = 1000 },
        adapter_limits = { maximum_request_bytes = 1048576, maximum_response_bytes = 1048576 },
        policy_id = "pilot-independent-checks", provider_profile_id = "pilot-independent-checks", platform = "linux-x86_64",
        nodes = [], edges = [], controls = { cancel = true, pause = false, resume = false },
        bounds = { max_nodes = 8, max_edges = 16, max_log_references = 32, max_log_read_bytes = 4096, max_total_log_bytes = 65536 },
      },
    }],
    bounds = {
      max_request_bytes = 1048576, max_response_bytes = 4194304, max_header_bytes = 4096, max_connections = 4,
      timeout_seconds = 120, poll_interval_ms = 100, max_projects = 1, max_runs = 16,
      max_artifact_bytes = 524288, max_artifacts = 64, max_run_artifact_bytes = 4194304, max_total_artifact_bytes = 16777216,
      max_log_read_bytes = 65536, max_requests = 64, max_events_per_run = 64, max_state_bytes = 16777216,
    },
  },
}
