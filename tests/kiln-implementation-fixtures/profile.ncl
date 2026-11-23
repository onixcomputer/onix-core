# Human-reviewed configuration for a closed, synthetic local VM only.
let Digest =
  std.contract.from_predicate (fun value =>
    std.is_string value && std.string.is_match "^[0-9a-f]{64}$" value
  )
in
let Program = { path | String, blake3 | Digest } in
let runtime = fun selector => { runtime = selector } in
fun raw =>
  let input =
    raw
      | {
        seed_identity | Digest,
        verification_identity | Digest,
        output_contract_identity | Digest,
        base | { contract_version | std.contract.from_predicate (fun v => v == 1), provider_namespace | String, native_kind | String, native_id | String },
        python | Program,
        git | Program,
        worker | Program,
        sandbox | Program,
        relay | Program,
        shell | Program,
        lattice | Program,
        fixture_helper | Program,
        worker_revision | String,
        acceptance_ids | Array String,
        remote_identity | Digest,
      }
  in
  let root = "/var/lib/kiln-implementation" in
  let repository = "qualification/disposable" in
  let acceptance = [{ id = "accepted", statement = "The exact scripted result bytes are produced without changing protected inputs" }] in
  let common = {
    project = "qualification",
    base = input.base,
    requested_outcome = "KILN_SCRIPTED_TASK: scripted-model-001: create only src/scripted_model_result.txt with the exact reviewed bytes",
    acceptance = acceptance,
    permitted_paths = ["src/scripted_model_result.txt"],
    permitted_effects = ["write_source"],
    verification_profile = input.verification_identity,
    budget = { attempts = 3, minutes_per_attempt = 2 },
    terminal_policy = "verified_pull_request",
    priority = 1,
  }
  in
  {
    models = import "models.ncl",
    verification = {
      schema = "kiln.verification-profile.v1",
      repository = repository,
      # Only native prepare-verification-profile turns these seed identities into
      # admitted toolchain/environment identities. The seed binds real input bytes.
      toolchain = input.seed_identity,
      environment_identity = input.seed_identity,
      environment = { LANG = "C.UTF-8", LC_ALL = "C.UTF-8", PYTHONDONTWRITEBYTECODE = "1" },
      checks = [
        {
          id = "acceptance",
          kind = "test",
          program = input.python,
          arguments = ["-I", "-B", "-c", "from pathlib import Path; import json; actual=Path('src/scripted_model_result.txt').read_bytes(); expected=b'scripted model fixture changed this file\\n'; assert actual==expected, (actual,expected); Path('observed.json').write_text(json.dumps({'exact_bytes':True,'scope':'synthetic-local-only'})+'\\n')"],
          prerequisites = [],
          acceptance = input.acceptance_ids,
          artifacts = ["observed.json"],
          timeout_ms = 10000,
        }
      ],
      reproducer = "acceptance",
      protected_paths = ["src/task.md", ".cairn"],
      allow_already_satisfied = false,
      cairn = null,
    },
    configuration = {
      "enrollment.json" = { repositories = [repository], actors = ["operator"] },
      "github-policy.json" =
        common
        & {
          repository = { owner = "qualification", repository = "disposable", repository_id = 1, allow_fork_pull_requests = false },
          dependencies = [],
        },
      "cairn-policy.json" = common & { repository = repository, actor = "operator" },
      "worker-transport-profile.json" = {
        schema = "kiln.lattice-implementation-cli.v2",
        lattice_program = input.lattice.path,
        executable_blake3 = input.lattice.blake3,
        state_directory = "%{root}/lattice/implementation",
        output_directory = "%{root}/lattice/observations",
      },
    },
    runtime_template = {
      schema = "onix.kiln.runtime-template.v1",
      scope = "synthetic-local-only",
      fixture_admission = input.fixture_helper,
      dispatch = {
        "attempt.json" = {
          schema = "lattice.implementation-attempt-run.v3",
          envelope = {
            schema = "lattice.implementation-attempt-envelope.v1",
            work_id = runtime "work",
            work_version = runtime "work_revision",
            source_kind = runtime "source_kind",
            source_id = runtime "source_id",
            repository = repository,
            base = runtime "base_oid",
            readiness_snapshot = runtime "readiness_snapshot",
            task_spec_digest = runtime "acceptance_digest",
            verification_profile = runtime "verification_profile",
            attempt_id = runtime "attempt",
            fence = runtime "fence",
            workspace_id = runtime "workspace",
            worker_profile = input.seed_identity,
            budget = { max_turns = 4, max_seconds = 90, max_cost_micros = 0 },
            policy_digest = input.seed_identity,
          },
          admitted_envelope = "",
          expires_at_ms = runtime "expires_at_ms",
          workspace_root = runtime "workspace_root",
          read_paths = ["src", ".cairn"],
          write_paths = ["src/scripted_model_result.txt"],
          # The worker has no network device; Lattice's host-side broker, run by
          # the dispatcher inside the closed fixture namespace, is its only route.
          network = false,
          program = input.worker.path,
          sandbox_program = input.sandbox.path,
          omp = {
            revision = input.worker_revision,
            executable_blake3 = input.worker.blake3,
            base_identity = std.string.join "" (std.array.replicate 64 "0"),
            model = "lattice/scripted-v1",
            prompt = "KILN_SCRIPTED_TASK: scripted-model-001. Use the write tool to create src/scripted_model_result.txt containing exactly scripted model fixture changed this file followed by one newline. Do not edit other files. Do not run shell commands.",
            model_broker = {
              schema = "lattice.candidate-model-broker.v1",
              endpoint = "http://127.0.0.1:18700/v1/chat/completions",
              model = "scripted-v1",
              credential = null,
              relay = input.relay,
              shell = input.shell,
              sandbox_blake3 = input.sandbox.blake3,
              expires_at_ms = runtime "expires_at_ms",
              max_requests = 4,
            },
          },
          worker_compute = { kind = "host_local" },
          execution_binding = {
            schema = "lattice.execution-binding.v1",
            compute = { kind = "host_local" },
            model_routes = { kind = "routes", routes = [{ name = "primary", route_identity = "blake3:%{std.string.join "" (std.array.replicate 64 "0")}" }] },
          },
          output_limit_bytes = 1048576,
          allow_unchanged = false,
        },
        "dispatch-plan.json" = {
          schema = "kiln.implementation-dispatch-plan.v2",
          work_identity = runtime "work",
          work_revision = runtime "work_revision",
          attempt_identity = runtime "attempt",
          fence = runtime "fence",
          repository = repository,
          base = runtime "base",
          workspace = { identity = runtime "workspace", isolation = "isolated_snapshot", network = false, credentials = false },
          provider_profile = "scripted-local-omp",
          permitted_paths = ["src/scripted_model_result.txt"],
          permitted_effects = ["write_source"],
          controls = { cancel = true, pause = false, resume = false },
          deadline_minutes = 2,
          token_budget = 4096,
          invocation_budget = 4,
          expected_output = input.output_contract_identity,
        },
        "admission-observations.json" = [],
        "verification-profile.json" = { runtime = "verification_profile_document" },
        "verifier-authority.json" = {
          repository = repository,
          repository_root = "%{root}/verifier/repository",
          scratch_root = "%{root}/verifier/scratch",
          git = input.git,
          worker_uid = 931,
        },
      },
      publication = {
        "publication.json" = {
          schema = "kiln.implementation-publication.v1",
          work_identity = runtime "work",
          work_revision = runtime "work_revision",
          attempt = runtime "attempt",
          fence = runtime "fence",
          handoff = runtime "handoff",
          verification = runtime "verification",
          repository = repository,
          base = runtime "base",
          base_branch = "main",
          candidate = runtime "candidate",
          tree = runtime "tree",
          branch = runtime "publication_branch",
          title = "Scripted local implementation fixture",
          body = "Synthetic local source edit, independently verified against protected exact-byte checks. Scripted authless model only; no live model, remote GitHub, retained guest, or cross-host qualification.",
        },
        "publication-source-profile.json" = {
          schema = "kiln.github-publication-source.v1",
          repository_path = "%{root}/verifier/repository",
          remote = import "remote.ncl",
          remote_identity = input.remote_identity,
          fixture = true,
        },
      },
    },
    # Input to Kiln's config/fair-admission-host-owner.ncl: one registered
    # host-local owner, so a reserved attempt's dispatch carries Kiln's budget
    # `lineage` and every post-dispatch stage must name the sent request.
    host_owner_input = {
      provider = "kiln-scripted-host",
      host = "kiln-scripted",
      generation = 1,
      capacity = { worker_slots = 1 },
      observation_ttl_ms = 600000,
      reservation_ttl_ms = 3600000,
      campaign = "scripted_qualification",
      tenant = "kiln_scripted",
      deadline_ms = 1830297600000,
      quota = { worker_slots = 4 },
      per_work = { worker_slots = 1 },
      limits = {
        max_items = 8,
        max_bytes = 1048576,
        max_wait_ms = 86400000,
        max_observation_age_ms = 900000,
        max_retry_after_ms = 60000,
        max_children = 1,
        max_active = 1,
      },
      repositories = [
        {
          repository = repository,
          classes = [{ name = "bug", project = "qualification", verification_profile = input.verification_identity }],
        }
      ],
    },
    ci_service_seed = {
      schema = "kiln.web-service.v1",
      service_id = "kiln-scripted-canonical-ci",
      listen_address = "127.0.0.1:19443",
      origin = "https://localhost:19443",
      tls = { certificate_path = "/run/kiln-scripted-ci/cert.pem", private_key_path = "/run/kiln-scripted-ci/key.pem", min_version = "TLS1.3" },
      operator_token_file = "/run/kiln-scripted-ci/operator.token",
      worker_token_file = "/run/kiln-scripted-ci/worker.token",
      state_directory = "%{root}/canonical-ci",
      projects = [
        {
          id = "qualification",
          label = "Synthetic local independent verification",
          repository_path = "%{root}/verifier/repository",
          reference = "refs/heads/main",
          source_limits = { max_entries = 4096, max_path_bytes = 4096, max_file_bytes = 4194304, max_total_bytes = 67108864 },
          workflow = {
            socket_path = "/run/kiln-scripted-ci/lattice.sock",
            allowed_user_ids = [933],
            transport_limits = { maximum_frame_bytes = 1048576, maximum_log_bytes = 65536, maximum_connections = 4, read_deadline_milliseconds = 1000, write_deadline_milliseconds = 1000 },
            adapter_limits = { maximum_request_bytes = 1048576, maximum_response_bytes = 1048576 },
            policy_id = "scripted-independent-checks",
            provider_profile_id = "scripted-independent-checks",
            platform = "linux-x86_64",
            nodes = [{ id = "acceptance", kind = "test", effect_class = "test", adapter_kind = "local", operation_identity = input.seed_identity }],
            edges = [],
            controls = { cancel = true, pause = false, resume = false },
            bounds = { max_nodes = 8, max_edges = 16, max_log_references = 32, max_log_read_bytes = 4096, max_total_log_bytes = 65536 },
          },
        }
      ],
      bounds = {
        max_request_bytes = 1048576,
        max_response_bytes = 4194304,
        max_header_bytes = 4096,
        max_connections = 4,
        timeout_seconds = 120,
        poll_interval_ms = 100,
        max_projects = 1,
        max_runs = 16,
        max_artifact_bytes = 524288,
        max_artifacts = 64,
        max_run_artifact_bytes = 4194304,
        max_total_artifact_bytes = 16777216,
        max_log_read_bytes = 65536,
        max_requests = 64,
        max_events_per_run = 64,
        max_state_bytes = 16777216,
      },
    },
  }
