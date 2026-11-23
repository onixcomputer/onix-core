# Typed constructor for one native selected-Cairn campaign drive profile.
# The caller supplies exact owner/source/provider inputs; executable identity always
# comes from the explicitly selected immutable cohort manifest.
let NonEmpty =
  std.contract.from_predicate (fun value =>
    std.is_string value && std.string.length value > 0
  )
in
let AbsolutePath =
  std.contract.from_predicate (fun value =>
    std.is_string value && std.string.is_match "^/[^\\x00]+$" value
  )
in
let Digest =
  std.contract.from_predicate (fun value =>
    std.is_string value && std.string.is_match "^[0-9a-f]{64}$" value
  )
in
let Positive =
  std.contract.from_predicate (fun value =>
    std.is_number value && value > 0
  )
in
let BoundedOperations =
  std.contract.from_predicate (fun value =>
    std.is_number value && value >= 1 && value <= 128
  )
in
let ExternalRef = {
  contract_version | std.contract.from_predicate (fun value => value == 1),
  provider_namespace | NonEmpty,
  native_kind | NonEmpty,
  native_id | NonEmpty,
}
in
let Entry = { resolved_path | AbsolutePath, blake3 | Digest, .. }
in
let Role = {
  program | AbsolutePath,
  arguments | Array String,
  blake3 | Digest,
  uid | Positive,
  gid | Positive,
}
in
let Acceptance = { id | NonEmpty, statement | NonEmpty }
in
let ImplementationPolicy = {
  repository | NonEmpty,
  project | NonEmpty,
  base | ExternalRef,
  actor | NonEmpty,
  requested_outcome | NonEmpty,
  acceptance | Array Acceptance,
  permitted_paths | Array NonEmpty,
  permitted_effects | Array NonEmpty,
  verification_profile | Digest,
  budget | { attempts | Positive, minutes_per_attempt | Positive },
  terminal_policy | NonEmpty,
  priority | std.contract.from_predicate (fun value => std.is_number value && value >= 0 && value <= 255),
}
in
let GithubInput = {
  enrollment | AbsolutePath,
  remote_profile | AbsolutePath,
  publication_policy | { base_branch | NonEmpty, title | NonEmpty, body | String },
  landing_policy | { required_checks | Array NonEmpty, required_approvals | std.contract.from_predicate (fun value => std.is_number value && value >= 0 && value <= 16) },
  lifecycle_action | std.contract.from_predicate (fun value => value == "observe_reviewed_sync" || value == "observe_reviewed_archive"),
  lifecycle_receipt_template | NonEmpty,
  repository | AbsolutePath,
  authoritative_report_directory | AbsolutePath,
  timeout_ms | std.contract.from_predicate (fun value => std.is_number value && value > 0 && value <= 300000),
}
in
let NativeGitInput = {
  enrollment | AbsolutePath,
  service_profile | AbsolutePath,
  review_profile | AbsolutePath,
  repository_path | AbsolutePath,
  change_id | NonEmpty,
  remote
    | {
      remote_name | NonEmpty,
      remote_url | NonEmpty,
      transport | std.contract.from_predicate (fun value => value == "https" || value == "ssh_strict_host_key"),
      ssh_host_key_sha256 | NonEmpty | optional,
    },
  provider_profile | NonEmpty,
  expected_old_target | ExternalRef,
  target_ref | NonEmpty,
  authoritative_report_directory | AbsolutePath,
  lifecycle_action | std.contract.from_predicate (fun value => value == "observe_reviewed_sync" || value == "observe_reviewed_archive"),
  lifecycle_receipt_template | NonEmpty,
}
in
let VerificationRoutes =
  std.contract.from_predicate (fun value =>
    std.is_record value
    && (
      let entries = std.record.to_array value in
      std.array.length entries > 0
      && std.array.length (
        std.array.filter
          (fun entry =>
            std.string.is_match "^[0-9a-f]{64}$" entry.field
            && std.is_record entry.value
            && std.record.has_field "ci_service_profile" entry.value
            && std.record.has_field "verification_profile" entry.value
            && std.is_string entry.value.ci_service_profile
            && std.is_string entry.value.verification_profile
            && std.string.is_match "^/[^\\x00]+$" entry.value.ci_service_profile
            && std.string.is_match "^/[^\\x00]+$" entry.value.verification_profile
          )
          entries
      ) == std.array.length entries
    )
  )
in
let DeliveryInput =
  std.contract.from_predicate (fun value =>
    std.is_record value
    && std.record.has_field "route" value
    && std.record.has_field "github" value
    && std.record.has_field "native_git" value
    && (
      (value.route == "github_pull_request" && value.github != null && value.native_git == null)
      || (value.route == "native_git" && value.github == null && value.native_git != null)
    )
  )
in
let Inputs_ = {
  campaign_id | NonEmpty,
  verification_routes | VerificationRoutes,
  campaign_database | AbsolutePath,
  implementation_database | AbsolutePath,
  decision_contexts | { _ : AbsolutePath } | default = {},
  verifier_authority | AbsolutePath,
  bound_input_directory | AbsolutePath,
  candidate_export_directory | AbsolutePath,
  worker
    | {
      dispatch_plan | AbsolutePath,
      request | AbsolutePath,
      admission_observations | Dyn | default = null,
    },
  native_cairn
    | {
      repository_root | AbsolutePath,
      source | ExternalRef,
      implementation_policy | ImplementationPolicy,
    },
  delivery | DeliveryInput,
  claim_lease_ms | Positive,
  maximum_operations | BoundedOperations,
  workspace
    | {
      repository | NonEmpty,
      repository_path | AbsolutePath,
      work_root | AbsolutePath,
      max_entries | Positive,
      max_path_bytes | Positive,
      max_file_bytes | Positive,
      max_total_bytes | Positive,
    },
}
in
{
  Inputs = Inputs_,
  generate = fun cohort inputs runtime driveContract =>
    let selected = inputs | Inputs_ in
    let manifest =
      cohort
        | {
          entries
            | {
              coordinator | Entry,
              verifier | Entry,
              dispatch | Entry,
              lattice | Entry,
              cairn | Entry,
              native_git | Entry,
              ..
            },
          ..
        }
    in
    let runtime =
      runtime
        | {
          enrollment | AbsolutePath,
          transport_profile | AbsolutePath,
          cairn_policy_path | AbsolutePath,
          campaign_credential_path | Dyn,
          setpriv | AbsolutePath,
          setpriv_blake3 | Digest,
          cairn_policy_identity | Digest,
          coordinator_uid | Positive,
          executor_uid | Positive,
          publisher_uid | Positive,
          verifier_uid | Positive,
          data_gid | Positive,
        }
    in
    let role = fun entry runUid commandArguments =>
      {
        program = entry.resolved_path,
        arguments = commandArguments,
        blake3 = entry.blake3,
        uid = runUid,
        gid = runtime.data_gid,
      } | driveContract.RoleProgram
    in
    let selectedDelivery =
      if selected.delivery.route == "github_pull_request" then
        let selectedGithub = selected.delivery.github | GithubInput in
        {
          route = "github_pull_request",
          github =
            selectedGithub
            & {
              secret_file = runtime.campaign_credential_path,
              publisher = role manifest.entries.coordinator runtime.publisher_uid [],
              integrator = role manifest.entries.coordinator runtime.publisher_uid [],
              lifecycle_observer = role manifest.entries.coordinator runtime.publisher_uid [],
            },
        }
      else
        let selectedNativeGit = selected.delivery.native_git | NativeGitInput in
        {
          route = "native_git",
          native_git =
            selectedNativeGit
            & {
              qualifier = role manifest.entries.native_git runtime.publisher_uid [],
              lifecycle_observer = role manifest.entries.native_git runtime.publisher_uid [],
            },
        }
    in
    {
      schema = "kiln.implementation-campaign-drive.v1",
      campaign_id = selected.campaign_id,
      campaign_database = selected.campaign_database,
      implementation_database = selected.implementation_database,
      verification_routes = selected.verification_routes,
      verifier_authority = selected.verifier_authority,
      decision_contexts = selected.decision_contexts,
      worker =
        {
          database = selected.implementation_database,
          enrollment = runtime.enrollment,
          dispatch_plan = selected.worker.dispatch_plan,
          request = selected.worker.request,
          transport_profile = runtime.transport_profile,
        }
        & (
          if selected.worker.admission_observations == null then
            {}
          else
            {
              admission_observations = selected.worker.admission_observations,
            }
        ),
      candidate_export = { output_parent = selected.candidate_export_directory },
      roles = {
        setpriv = runtime.setpriv,
        setpriv_blake3 = runtime.setpriv_blake3,
        worker = role manifest.entries.dispatch runtime.executor_uid [],
        exporter = role manifest.entries.lattice runtime.executor_uid ["implementation-attempt", "export-candidate"],
        capture = role manifest.entries.coordinator runtime.verifier_uid ["capture-candidate"],
        verifier = role manifest.entries.verifier runtime.verifier_uid ["verify-implementation"],
      },
      native_cairn = {
        cairn = {
          executable = manifest.entries.cairn.resolved_path,
          repository_root = selected.native_cairn.repository_root,
          policy_path = runtime.cairn_policy_path,
          executable_identity = manifest.entries.cairn.blake3,
          policy_identity = runtime.cairn_policy_identity,
        },
        implementation_policy = selected.native_cairn.implementation_policy,
        source = selected.native_cairn.source,
      },
      delivery = selectedDelivery,
      claim_lease_ms = selected.claim_lease_ms,
      maximum_operations = selected.maximum_operations,
      workspace = selected.workspace,
    } | driveContract.Profile,
}
