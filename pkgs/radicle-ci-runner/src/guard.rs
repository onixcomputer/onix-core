//! Pure exact-revision canonical compare-and-swap admission.
//!
//! Radicle evaluator, Git graph, filesystem, and ref mutation effects remain in
//! the binary shell. This module only validates supplied typed observations.

use serde::Serialize;

use crate::AdmittedEventV1;
use crate::BLAKE3_HEX_LENGTH;
use crate::ForgeGuardPolicyV1;
use crate::GIT_OID_HEX_LENGTH;
use crate::GUARD_DECISION_SCHEMA;
use crate::GuardDecisionV1;
use crate::GuardIssue;
use crate::GuardReportV1;
use crate::JobResultV1;
use crate::LiveGuardObservationV1;
use crate::MAX_TEXT_BYTES;
use crate::REQUIRED_SIGNED_REFS_FEATURE;
use crate::RESULT_SCHEMA;
use crate::RunnerConfigV1;
use crate::RunnerDisposition;
use crate::STATUS_MARKER;
use crate::STATUS_SCHEMA;
use crate::SignedStatusV1;
use crate::TriggerClass;
use crate::VALENCE_ADMISSION_SCHEMA;
use crate::ValenceAdmissionReceiptV1;
use crate::validate_event;
use crate::validate_result;

// r[impl onix.radicle_ci.canonical_guard.status]
// r[impl onix.radicle_ci.canonical_guard.core]
// r[impl onix.radicle_ci.canonical_guard.authority]

pub const STATUS_CLAIM_SCOPE: &str = "signed-bot-ci-observation-only";
pub const STATUS_NON_CLAIM: &str = "signed CI status records one bounded observation; it is not merge, canonical-ref, or release approval";
pub const GUARD_CLAIM_SCOPE: &str = "operator-atomic-compare-and-swap-input";
pub const VALENCE_CLAIM_SCOPE: &str = "external-guarded-compare-and-swap-input";
pub const SUCCEEDED_DISPOSITION: &str = "succeeded";
pub const CANONICAL_TARGET_REF: &str = "refs/heads/main";
pub const SUCCESS_EXIT_CODE: i32 = 0;

#[derive(Serialize)]
struct GuardDecisionIdentity<'a> {
    schema: &'static str,
    ci_policy_blake3: &'a str,
    valence_revision: &'a str,
    rid: &'a str,
    patch_id: &'a str,
    revision_id: &'a str,
    target_ref: &'a str,
    expected_old_oid: &'a str,
    candidate_oid: &'a str,
    job_id: &'a str,
    event_blake3: &'a str,
    result_blake3: &'a str,
    status_blake3: &'a str,
    valence_receipt_blake3: &'a str,
    approving_delegates: &'a [String],
    signing_delegates: &'a [String],
    threshold: usize,
    claim_scope: &'a str,
    required_non_claims: &'a [String],
}

pub const ADMISSION_MIGRATION_NON_CLAIM: &str = "migration records normalized source metadata and observed native COB state; it does not prove source export completeness, source actor authenticity, original signature or timestamp preservation, or semantic equivalence";
pub const ADMISSION_REVIEW_NON_CLAIM: &str = "imported review metadata is recorded attribution only and does not create Radicle approval, merge eligibility, delegate authority, or canonical-ref authority";
pub const ADMISSION_CI_NON_CLAIM: &str = "CI admission is bounded input for an external guarded compare-and-swap; it is not protocol-enforced mandatory CI, bypass-proof delegate behavior, canonical mutation, CI correctness, or release readiness";
pub const GUARD_PROTOCOL_NON_CLAIM: &str = "guard admission does not provide Radicle protocol-enforced mandatory CI, bypass-proof delegate behavior, or merge semantics";
pub const GUARD_AUTHORITY_NON_CLAIM: &str = "guard execution does not grant canonical authority to the CI bot, credentialless runner, seeds, or Valence";
pub const GUARD_EXECUTION_NON_CLAIM: &str = "guard execution receipt does not prove CI correctness, seed convergence, replication, release readiness, or post-update durability";

/// Build the closed payload written inside the bot's signed patch comment.
///
/// # Errors
/// Returns a stable diagnostic when event/result/config facts do not agree.
pub fn build_signed_status(
    config: &RunnerConfigV1,
    event: &AdmittedEventV1,
    result: &JobResultV1,
) -> Result<SignedStatusV1, crate::Diagnostic> {
    validate_event(config, event)?;
    validate_result(event, result)?;
    if event.trigger != TriggerClass::Patch {
        return Err(crate::Diagnostic {
            code: "ci-status-trigger",
            message: "signed status is only defined for patch revisions",
        });
    }
    let patch_id = event.patch_id.clone().ok_or(crate::Diagnostic {
        code: "ci-status-patch",
        message: "signed status lacks a patch ID",
    })?;
    let revision_id = event.revision_id.clone().ok_or(crate::Diagnostic {
        code: "ci-status-revision",
        message: "signed status lacks a revision ID",
    })?;
    let event_blake3 = canonical_blake3(event)?;
    let result_blake3 = canonical_blake3(result)?;
    let mut status = SignedStatusV1 {
        schema: STATUS_SCHEMA.to_owned(),
        status_blake3: String::new(),
        policy_blake3: event.policy_blake3.clone(),
        rid: event.rid.clone(),
        patch_id,
        revision_id,
        check_name: config.check_name.clone(),
        job_id: event.job_id.clone(),
        object_oid: event.object_oid.clone(),
        disposition: result.disposition,
        artifact_blake3: result.artifact_blake3.clone(),
        event_blake3,
        result_blake3,
        claim_scope: STATUS_CLAIM_SCOPE.to_owned(),
        non_claim: STATUS_NON_CLAIM.to_owned(),
    };
    status.status_blake3 = expected_status_blake3(&status)?;
    Ok(status)
}

/// Render one strict marker/JSON line followed by a human-readable boundary.
///
/// # Errors
/// Returns a diagnostic if typed status serialization fails.
pub fn render_signed_status(status: &SignedStatusV1) -> Result<String, crate::Diagnostic> {
    validate_signed_status(status)?;
    let json = serde_json::to_string(status).map_err(|_| crate::Diagnostic {
        code: "ci-status-serialize",
        message: "signed status could not be serialized",
    })?;
    Ok(format!(
        "{STATUS_MARKER}\n{json}\n\nOnix CI `{}` for `{}`: **{:?}**. Artifact BLAKE3 `{}`. Scope: bounded observation only; this is not merge, canonical-ref, or release approval.",
        status.job_id, status.object_oid, status.disposition, status.artifact_blake3
    ))
}

/// Parse a closed status payload from a signed comment body.
///
/// # Errors
/// Returns a diagnostic for missing markers, multiline/unknown JSON, or identity drift.
pub fn parse_signed_status(body: &str) -> Result<SignedStatusV1, crate::Diagnostic> {
    let mut lines = body.lines();
    if lines.next() != Some(STATUS_MARKER) {
        return Err(crate::Diagnostic {
            code: "ci-status-marker",
            message: "signed status marker is absent",
        });
    }
    let json = lines.next().ok_or(crate::Diagnostic {
        code: "ci-status-json",
        message: "signed status JSON line is absent",
    })?;
    if json.is_empty() || lines.any(|line| line == STATUS_MARKER) {
        return Err(crate::Diagnostic {
            code: "ci-status-shape",
            message: "signed status body is malformed or repeated",
        });
    }
    let status = serde_json::from_str::<SignedStatusV1>(json).map_err(|_| crate::Diagnostic {
        code: "ci-status-json",
        message: "signed status JSON is malformed or contains unknown fields",
    })?;
    validate_signed_status(&status)?;
    Ok(status)
}

/// Validate and materialize a deterministic exact-revision guard decision.
#[must_use]
pub fn evaluate_canonical_guard(
    policy: &ForgeGuardPolicyV1,
    event: &AdmittedEventV1,
    result: &JobResultV1,
    valence: &ValenceAdmissionReceiptV1,
    live: &LiveGuardObservationV1,
) -> GuardReportV1 {
    let mut issues = Vec::new();
    validate_guard_policy(policy, &mut issues);
    let event_blake3 = canonical_blake3(event).unwrap_or_default();
    let result_blake3 = canonical_blake3(result).unwrap_or_default();
    validate_event_result(
        policy,
        event,
        result,
        &event_blake3,
        &result_blake3,
        &mut issues,
    );
    validate_valence_receipt(policy, valence, &event_blake3, &result_blake3, &mut issues);
    validate_live_observation(
        policy,
        event,
        result,
        valence,
        live,
        &event_blake3,
        &result_blake3,
        &mut issues,
    );
    issues.sort();
    issues.dedup();
    if !issues.is_empty() {
        return GuardReportV1 {
            schema: GUARD_DECISION_SCHEMA.to_owned(),
            admitted: false,
            issues,
            decision: None,
        };
    }

    let claim_scope = GUARD_CLAIM_SCOPE.to_owned();
    let decision_blake3 = canonical_blake3(&GuardDecisionIdentity {
        schema: GUARD_DECISION_SCHEMA,
        ci_policy_blake3: &policy.ci_policy_blake3,
        valence_revision: &policy.valence_revision,
        rid: &policy.rid,
        patch_id: &live.patch_id,
        revision_id: &live.revision_id,
        target_ref: &policy.target_ref,
        expected_old_oid: &live.current_canonical_oid,
        candidate_oid: &live.candidate_oid,
        job_id: &event.job_id,
        event_blake3: &event_blake3,
        result_blake3: &result_blake3,
        status_blake3: &live.status.status_blake3,
        valence_receipt_blake3: &valence.receipt_blake3,
        approving_delegates: &live.approving_delegates,
        signing_delegates: &live.signing_delegates,
        threshold: policy.threshold,
        claim_scope: &claim_scope,
        required_non_claims: &policy.required_non_claims,
    })
    .unwrap_or_default();
    GuardReportV1 {
        schema: GUARD_DECISION_SCHEMA.to_owned(),
        admitted: true,
        issues: Vec::new(),
        decision: Some(GuardDecisionV1 {
            schema: GUARD_DECISION_SCHEMA.to_owned(),
            decision_blake3,
            ci_policy_blake3: policy.ci_policy_blake3.clone(),
            valence_revision: policy.valence_revision.clone(),
            rid: policy.rid.clone(),
            patch_id: live.patch_id.clone(),
            revision_id: live.revision_id.clone(),
            target_ref: policy.target_ref.clone(),
            expected_old_oid: live.current_canonical_oid.clone(),
            candidate_oid: live.candidate_oid.clone(),
            job_id: event.job_id.clone(),
            event_blake3,
            result_blake3,
            status_blake3: live.status.status_blake3.clone(),
            valence_receipt_blake3: valence.receipt_blake3.clone(),
            approving_delegates: live.approving_delegates.clone(),
            signing_delegates: live.signing_delegates.clone(),
            threshold: policy.threshold,
            claim_scope,
            required_non_claims: policy.required_non_claims.clone(),
        }),
    }
}

fn validate_guard_policy(policy: &ForgeGuardPolicyV1, issues: &mut Vec<GuardIssue>) {
    if policy.schema != crate::GUARD_POLICY_SCHEMA
        || policy.status_schema != STATUS_SCHEMA
        || policy.admission_schema != VALENCE_ADMISSION_SCHEMA
        || policy.event_schema != crate::EVENT_SCHEMA
        || policy.result_schema != RESULT_SCHEMA
        || !radicle_id(&policy.rid)
        || !blake3_digest(&policy.ci_policy_blake3)
        || !git_oid(&policy.valence_revision)
        || !did(&policy.bot_did)
        || policy.delegates.is_empty()
        || policy.threshold == 0
        || policy.threshold > policy.delegates.len()
        || !unique_sorted(&policy.delegates)
        || policy
            .delegates
            .iter()
            .any(|delegate| !did(delegate) || delegate == &policy.bot_did)
        || !one_line(&policy.required_check)
        || policy.target_ref != CANONICAL_TARGET_REF
        || policy.signed_refs_feature != REQUIRED_SIGNED_REFS_FEATURE
        || policy.admission_non_claims != admission_non_claims()
        || policy.required_non_claims != guard_non_claims()
    {
        push_issue(issues, "guard-policy", "policy");
    }
}

fn validate_event_result(
    policy: &ForgeGuardPolicyV1,
    event: &AdmittedEventV1,
    result: &JobResultV1,
    event_blake3: &str,
    result_blake3: &str,
    issues: &mut Vec<GuardIssue>,
) {
    if event.schema != policy.event_schema
        || event.policy_blake3 != policy.ci_policy_blake3
        || event.rid != policy.rid
        || event.trigger != TriggerClass::Patch
        || event
            .patch_id
            .as_deref()
            .is_none_or(|value| !git_oid(value))
        || event
            .revision_id
            .as_deref()
            .is_none_or(|value| !git_oid(value))
        || !git_oid(&event.object_oid)
        || event.signed_refs_feature != policy.signed_refs_feature
        || !blake3_digest(event_blake3)
    {
        push_issue(issues, "guard-event", "event");
    }
    if result.schema != policy.result_schema
        || result.job_id != event.job_id
        || result.rid != event.rid
        || result.trigger != event.trigger
        || result.object_oid != event.object_oid
        || result.patch_id != event.patch_id
        || result.revision_id != event.revision_id
        || result.disposition != RunnerDisposition::Succeeded
        || result.exit_code != Some(SUCCESS_EXIT_CODE)
        || !blake3_digest(&result.artifact_blake3)
        || !blake3_digest(result_blake3)
    {
        push_issue(issues, "guard-result", "result");
    }
}

fn validate_valence_receipt(
    policy: &ForgeGuardPolicyV1,
    receipt: &ValenceAdmissionReceiptV1,
    event_blake3: &str,
    result_blake3: &str,
    issues: &mut Vec<GuardIssue>,
) {
    let mut delegates = receipt.approving_delegates.clone();
    delegates.sort();
    let expected = canonical_blake3(&(
        VALENCE_ADMISSION_SCHEMA,
        &receipt.policy_blake3,
        &receipt.rid,
        &receipt.patch_id,
        &receipt.revision_id,
        &receipt.current_canonical_oid,
        &receipt.candidate_oid,
        &receipt.job_id,
        &receipt.event_blake3,
        &receipt.result_blake3,
        &receipt.bot_did,
        &delegates,
        receipt.threshold,
        &receipt.disposition,
        &receipt.claim_scope,
        &receipt.required_non_claims,
    ))
    .unwrap_or_default();
    if receipt.schema != policy.admission_schema
        || receipt.receipt_blake3 != expected
        || receipt.policy_blake3 != policy.ci_policy_blake3
        || receipt.rid != policy.rid
        || receipt.event_blake3 != event_blake3
        || receipt.result_blake3 != result_blake3
        || receipt.bot_did != policy.bot_did
        || receipt.threshold != policy.threshold
        || receipt.approving_delegates != delegates
        || receipt.approving_delegates.len() < policy.threshold
        || receipt
            .approving_delegates
            .iter()
            .any(|delegate| !policy.delegates.contains(delegate))
        || receipt.disposition != SUCCEEDED_DISPOSITION
        || receipt.claim_scope != VALENCE_CLAIM_SCOPE
        || receipt.required_non_claims != policy.admission_non_claims
        || !git_oid(&receipt.patch_id)
        || !git_oid(&receipt.revision_id)
        || !git_oid(&receipt.current_canonical_oid)
        || !git_oid(&receipt.candidate_oid)
    {
        push_issue(issues, "guard-valence-receipt", "valence");
    }
}

#[allow(clippy::too_many_arguments)]
fn validate_live_observation(
    policy: &ForgeGuardPolicyV1,
    event: &AdmittedEventV1,
    result: &JobResultV1,
    valence: &ValenceAdmissionReceiptV1,
    live: &LiveGuardObservationV1,
    event_blake3: &str,
    result_blake3: &str,
    issues: &mut Vec<GuardIssue>,
) {
    let event_patch = event.patch_id.as_deref().unwrap_or_default();
    let event_revision = event.revision_id.as_deref().unwrap_or_default();
    if live.rid != policy.rid
        || live.patch_id != event_patch
        || live.patch_id != valence.patch_id
        || live.revision_id != event_revision
        || live.revision_id != valence.revision_id
        || live.candidate_oid != event.object_oid
        || live.candidate_oid != result.object_oid
        || live.candidate_oid != valence.candidate_oid
        || live.current_canonical_oid != valence.current_canonical_oid
        || live.target_ref != policy.target_ref
        || live.base_oid != live.current_canonical_oid
        || !live.candidate_present
        || !live.candidate_is_descendant
        || !live.canonical_observation_current
        || !live.evaluator_verified
        || live.signed_refs_feature != policy.signed_refs_feature
    {
        push_issue(issues, "guard-live-patch", "live");
    }
    if validate_signed_status(&live.status).is_err()
        || live.status_author_did != policy.bot_did
        || live.status.policy_blake3 != policy.ci_policy_blake3
        || live.status.rid != policy.rid
        || live.status.patch_id != live.patch_id
        || live.status.revision_id != live.revision_id
        || live.status.check_name != policy.required_check
        || live.status.job_id != event.job_id
        || live.status.object_oid != live.candidate_oid
        || live.status.disposition != result.disposition
        || live.status.artifact_blake3 != result.artifact_blake3
        || live.status.event_blake3 != event_blake3
        || live.status.result_blake3 != result_blake3
    {
        push_issue(issues, "guard-live-status", "live.status");
    }
    if live.approving_delegates != valence.approving_delegates
        || live.approving_delegates.len() < policy.threshold
        || !unique_sorted(&live.approving_delegates)
        || live
            .approving_delegates
            .iter()
            .any(|delegate| !policy.delegates.contains(delegate))
    {
        push_issue(issues, "guard-live-approvals", "live.approving_delegates");
    }
    let signing_approvals = live
        .signing_delegates
        .iter()
        .filter(|delegate| live.approving_delegates.contains(delegate))
        .count();
    if live.signing_delegates.len() < policy.threshold
        || signing_approvals < policy.threshold
        || !unique_sorted(&live.signing_delegates)
        || live
            .signing_delegates
            .iter()
            .any(|delegate| !policy.delegates.contains(delegate))
    {
        push_issue(issues, "guard-live-signed-refs", "live.signing_delegates");
    }
}

fn validate_signed_status(status: &SignedStatusV1) -> Result<(), crate::Diagnostic> {
    if status.schema != STATUS_SCHEMA
        || status.status_blake3 != expected_status_blake3(status)?
        || !blake3_digest(&status.policy_blake3)
        || !radicle_id(&status.rid)
        || !git_oid(&status.patch_id)
        || !git_oid(&status.revision_id)
        || !one_line(&status.check_name)
        || !blake3_digest(&status.job_id)
        || !git_oid(&status.object_oid)
        || !blake3_digest(&status.artifact_blake3)
        || !blake3_digest(&status.event_blake3)
        || !blake3_digest(&status.result_blake3)
        || status.claim_scope != STATUS_CLAIM_SCOPE
        || status.non_claim != STATUS_NON_CLAIM
    {
        return Err(crate::Diagnostic {
            code: "ci-status-identity",
            message: "signed status shape or BLAKE3 identity is invalid",
        });
    }
    Ok(())
}

fn expected_status_blake3(status: &SignedStatusV1) -> Result<String, crate::Diagnostic> {
    canonical_blake3(&(
        STATUS_SCHEMA,
        &status.policy_blake3,
        &status.rid,
        &status.patch_id,
        &status.revision_id,
        &status.check_name,
        &status.job_id,
        &status.object_oid,
        status.disposition,
        &status.artifact_blake3,
        &status.event_blake3,
        &status.result_blake3,
        &status.claim_scope,
        &status.non_claim,
    ))
}

fn canonical_blake3(value: &impl Serialize) -> Result<String, crate::Diagnostic> {
    let bytes = serde_json::to_vec(value).map_err(|_| crate::Diagnostic {
        code: "guard-canonical-json",
        message: "guard identity facts could not be serialized",
    })?;
    Ok(blake3::hash(&bytes).to_hex().to_string())
}

fn admission_non_claims() -> Vec<String> {
    [
        ADMISSION_MIGRATION_NON_CLAIM,
        ADMISSION_REVIEW_NON_CLAIM,
        ADMISSION_CI_NON_CLAIM,
    ]
    .into_iter()
    .map(str::to_owned)
    .collect()
}

fn guard_non_claims() -> Vec<String> {
    [
        GUARD_PROTOCOL_NON_CLAIM,
        GUARD_AUTHORITY_NON_CLAIM,
        GUARD_EXECUTION_NON_CLAIM,
    ]
    .into_iter()
    .map(str::to_owned)
    .collect()
}

fn unique_sorted(values: &[String]) -> bool {
    values.windows(2).all(|window| window[0] < window[1])
}

fn one_line(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= MAX_TEXT_BYTES
        && !value.contains('\0')
        && !value.chars().any(char::is_control)
}

fn did(value: &str) -> bool {
    let prefix = "did:key:z";
    value.starts_with(prefix)
        && value.len() > prefix.len()
        && value.len() <= MAX_TEXT_BYTES
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b':')
}

fn radicle_id(value: &str) -> bool {
    let prefix = "rad:z";
    value.starts_with(prefix)
        && value.len() > prefix.len()
        && value.len() <= MAX_TEXT_BYTES
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b':')
}

fn git_oid(value: &str) -> bool {
    lower_hex(value, GIT_OID_HEX_LENGTH)
}

fn blake3_digest(value: &str) -> bool {
    lower_hex(value, BLAKE3_HEX_LENGTH)
}

fn lower_hex(value: &str, length: usize) -> bool {
    value.len() == length
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

fn push_issue(issues: &mut Vec<GuardIssue>, code: &str, path: &str) {
    issues.push(GuardIssue {
        code: code.to_owned(),
        path: path.to_owned(),
    });
}

#[cfg(test)]
mod tests {
    // r[verify onix.radicle_ci.canonical_guard.status]
    // r[verify onix.radicle_ci.canonical_guard.core]
    // r[verify onix.radicle_ci.canonical_guard.validation]

    use super::*;
    use crate::LockIdentityV1;
    use crate::RunnerLimitsV1;

    const RID: &str = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
    const POLICY: &str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const PATCH: &str = "1111111111111111111111111111111111111111";
    const REVISION: &str = "2222222222222222222222222222222222222222";
    const BASE: &str = "3333333333333333333333333333333333333333";
    const HEAD: &str = "4444444444444444444444444444444444444444";
    const BOT: &str = "did:key:z6Mbotbotbotbotbotbotbotbotbotbotbotbotbotbotbotbot";
    const DELEGATE_A: &str = "did:key:z6MdelegateAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    const DELEGATE_B: &str = "did:key:z6MdelegateBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB";
    const STRIPPED_HTML_MARKER: &str = "<!-- onix-radicle-ci-status:v1 -->";

    fn locks() -> LockIdentityV1 {
        LockIdentityV1 {
            cargo_toml_blake3: POLICY.to_owned(),
            cargo_lock_blake3: POLICY.to_owned(),
            flake_nix_blake3: POLICY.to_owned(),
            flake_lock_blake3: POLICY.to_owned(),
        }
    }

    fn runner_config() -> RunnerConfigV1 {
        RunnerConfigV1 {
            schema: crate::CONFIG_SCHEMA.to_owned(),
            rid: RID.to_owned(),
            signed_refs_feature: REQUIRED_SIGNED_REFS_FEATURE.to_owned(),
            production_seed: "z6Mkseed@127.0.0.1:8776".to_owned(),
            production_seed_node_id: "z6Mkseed".to_owned(),
            production_seed_address: "127.0.0.1:8776".to_owned(),
            reviewed_commit: BASE.to_owned(),
            policy_blake3: POLICY.to_owned(),
            check_name: "onix/ci/v1".to_owned(),
            bot_public_key: "ssh-ed25519 AAAA".to_owned(),
            bot_node_id: "z6Mbot".to_owned(),
            bot_fingerprint: "SHA256:bot".to_owned(),
            delegates: vec![DELEGATE_A.to_owned(), DELEGATE_B.to_owned()],
            expected_locks: locks(),
            command_program: "/nix/store/nix/bin/nix".to_owned(),
            command_arguments: vec!["build".to_owned(), "--no-update-lock-file".to_owned()],
            allowed_input_uris: vec!["github:NixOS/nixpkgs/revision".to_owned()],
            git_program: "/nix/store/git/bin/git".to_owned(),
            nix_program: "/nix/store/nix/bin/nix".to_owned(),
            nix_conf_dir: "/nix/store/nix-conf".to_owned(),
            tar_program: "/nix/store/tar/bin/tar".to_owned(),
            rad_program: "/nix/store/rad/bin/rad".to_owned(),
            ssh_program: "/nix/store/ssh/bin/ssh".to_owned(),
            storage_path: "/var/lib/bot/storage".to_owned(),
            bot_state_path: "/var/lib/bot".to_owned(),
            exchange_path: "/var/lib/exchange".to_owned(),
            runner_state_path: "/var/lib/runner".to_owned(),
            artifact_path: "/var/lib/artifacts".to_owned(),
            local_store_root: "/var/lib/runner/store".to_owned(),
            limits: RunnerLimitsV1 {
                timeout_ms: 1,
                stdin_max_bytes: 1,
                stdout_max_bytes: 1,
                stderr_max_bytes: 1,
                poll_interval_ms: 1,
                teardown_timeout_ms: 1,
                artifact_max_bytes: 1,
                memory_max_bytes: 1,
                cpu_quota_percent: 1,
                max_parallel_jobs: 1,
            },
        }
    }

    fn event() -> AdmittedEventV1 {
        let candidate = crate::CandidateV1 {
            rid: RID.to_owned(),
            trigger: TriggerClass::Patch,
            reference: format!("refs/cobs/xyz.radicle.patch/{PATCH}"),
            object_oid: HEAD.to_owned(),
            patch_id: Some(PATCH.to_owned()),
            revision_id: Some(REVISION.to_owned()),
            object_present_locally: true,
            object_is_current: true,
            signed_refs_feature: REQUIRED_SIGNED_REFS_FEATURE.to_owned(),
            delegate_alignment_verified: true,
            observed_locks: locks(),
        };
        crate::admit_candidate(&runner_config(), &candidate, POLICY).expect("event")
    }

    fn result(event: &AdmittedEventV1) -> JobResultV1 {
        JobResultV1 {
            schema: RESULT_SCHEMA.to_owned(),
            job_id: event.job_id.clone(),
            rid: event.rid.clone(),
            trigger: event.trigger,
            object_oid: event.object_oid.clone(),
            patch_id: event.patch_id.clone(),
            revision_id: event.revision_id.clone(),
            disposition: RunnerDisposition::Succeeded,
            exit_code: Some(SUCCESS_EXIT_CODE),
            stdout_observed_bytes: 1,
            stdout_retained_bytes: 1,
            stdout_blake3: POLICY.to_owned(),
            stderr_observed_bytes: 0,
            stderr_retained_bytes: 0,
            stderr_blake3: POLICY.to_owned(),
            artifact_bytes: 1,
            artifact_blake3: POLICY.to_owned(),
            status_authority: "non-delegate-patch-comment-only".to_owned(),
            claim_scope: "bounded-ci-observation".to_owned(),
            non_claims: crate::required_non_claims(),
        }
    }

    fn policy() -> ForgeGuardPolicyV1 {
        ForgeGuardPolicyV1 {
            schema: crate::GUARD_POLICY_SCHEMA.to_owned(),
            status_schema: STATUS_SCHEMA.to_owned(),
            admission_schema: VALENCE_ADMISSION_SCHEMA.to_owned(),
            event_schema: crate::EVENT_SCHEMA.to_owned(),
            result_schema: RESULT_SCHEMA.to_owned(),
            rid: RID.to_owned(),
            ci_policy_blake3: POLICY.to_owned(),
            valence_revision: "e822bdf5395d6e1a77786c538ac0aaa13ef8c165".to_owned(),
            bot_did: BOT.to_owned(),
            delegates: vec![DELEGATE_A.to_owned(), DELEGATE_B.to_owned()],
            threshold: 2,
            required_check: "onix/ci/v1".to_owned(),
            target_ref: CANONICAL_TARGET_REF.to_owned(),
            signed_refs_feature: REQUIRED_SIGNED_REFS_FEATURE.to_owned(),
            admission_non_claims: admission_non_claims(),
            required_non_claims: guard_non_claims(),
        }
    }

    fn radicle_cli_strip_editor_comments(input: &str) -> String {
        let ends_with_newline = input.ends_with('\n');
        let mut is_comment = false;
        let mut output = String::new();
        for line in input.lines() {
            if is_comment {
                if line.ends_with("-->") {
                    is_comment = false;
                }
                continue;
            }
            if line.starts_with("<!--") {
                is_comment = true;
                continue;
            }
            output.push_str(line);
            output.push('\n');
        }
        if !ends_with_newline {
            output.pop();
        }
        output
    }

    fn facts() -> (
        AdmittedEventV1,
        JobResultV1,
        SignedStatusV1,
        ValenceAdmissionReceiptV1,
        LiveGuardObservationV1,
    ) {
        let event = event();
        let result = result(&event);
        let status = build_signed_status(&runner_config(), &event, &result).expect("status");
        let event_blake3 = canonical_blake3(&event).expect("event digest");
        let result_blake3 = canonical_blake3(&result).expect("result digest");
        let delegates = vec![DELEGATE_A.to_owned(), DELEGATE_B.to_owned()];
        let mut receipt = ValenceAdmissionReceiptV1 {
            schema: VALENCE_ADMISSION_SCHEMA.to_owned(),
            receipt_blake3: String::new(),
            policy_blake3: POLICY.to_owned(),
            rid: RID.to_owned(),
            patch_id: PATCH.to_owned(),
            revision_id: REVISION.to_owned(),
            current_canonical_oid: BASE.to_owned(),
            candidate_oid: HEAD.to_owned(),
            job_id: event.job_id.clone(),
            event_blake3,
            result_blake3,
            bot_did: BOT.to_owned(),
            approving_delegates: delegates.clone(),
            threshold: 2,
            disposition: SUCCEEDED_DISPOSITION.to_owned(),
            claim_scope: VALENCE_CLAIM_SCOPE.to_owned(),
            required_non_claims: admission_non_claims(),
        };
        receipt.receipt_blake3 = canonical_blake3(&(
            VALENCE_ADMISSION_SCHEMA,
            &receipt.policy_blake3,
            &receipt.rid,
            &receipt.patch_id,
            &receipt.revision_id,
            &receipt.current_canonical_oid,
            &receipt.candidate_oid,
            &receipt.job_id,
            &receipt.event_blake3,
            &receipt.result_blake3,
            &receipt.bot_did,
            &receipt.approving_delegates,
            receipt.threshold,
            &receipt.disposition,
            &receipt.claim_scope,
            &receipt.required_non_claims,
        ))
        .expect("receipt digest");
        let live = LiveGuardObservationV1 {
            rid: RID.to_owned(),
            patch_id: PATCH.to_owned(),
            revision_id: REVISION.to_owned(),
            base_oid: BASE.to_owned(),
            candidate_oid: HEAD.to_owned(),
            target_ref: CANONICAL_TARGET_REF.to_owned(),
            current_canonical_oid: BASE.to_owned(),
            candidate_present: true,
            candidate_is_descendant: true,
            canonical_observation_current: true,
            evaluator_verified: true,
            signed_refs_feature: REQUIRED_SIGNED_REFS_FEATURE.to_owned(),
            status_author_did: BOT.to_owned(),
            status,
            approving_delegates: delegates.clone(),
            signing_delegates: delegates,
        };
        (event, result, live.status.clone(), receipt, live)
    }

    #[test]
    fn status_round_trip_is_closed_and_tamper_evident() {
        let (event, result, status, _, _) = facts();
        let rendered = render_signed_status(&status).expect("rendered status");
        assert_eq!(parse_signed_status(&rendered), Ok(status.clone()));
        let unknown = rendered.replacen(
            &format!("\"schema\":\"{}\"", status.schema),
            &format!("\"unknown\":true,\"schema\":\"{}\"", status.schema),
            1,
        );
        assert_eq!(
            parse_signed_status(&unknown).unwrap_err().code,
            "ci-status-json"
        );
        let mut failed = result;
        failed.disposition = RunnerDisposition::TimedOut;
        failed.exit_code = None;
        let failed_status =
            build_signed_status(&runner_config(), &event, &failed).expect("bounded failed status");
        assert_eq!(failed_status.disposition, RunnerDisposition::TimedOut);
    }

    #[test]
    fn visible_status_marker_survives_radicle_comment_sanitization() {
        let (_, _, status, _, _) = facts();
        let rendered = render_signed_status(&status).expect("rendered status");
        assert!(!STATUS_MARKER.starts_with("<!--"));
        assert_eq!(radicle_cli_strip_editor_comments(&rendered), rendered);
        assert_eq!(parse_signed_status(&rendered), Ok(status));

        let stripped = rendered.replacen(STATUS_MARKER, STRIPPED_HTML_MARKER, 1);
        assert!(radicle_cli_strip_editor_comments(&stripped).is_empty());
        assert_eq!(
            parse_signed_status(&stripped).unwrap_err().code,
            "ci-status-marker"
        );
    }

    #[test]
    fn complete_exact_revision_admits_deterministically() {
        let (event, result, _, receipt, live) = facts();
        let first = evaluate_canonical_guard(&policy(), &event, &result, &receipt, &live);
        let second = evaluate_canonical_guard(&policy(), &event, &result, &receipt, &live);
        assert_eq!(first, second);
        assert!(first.admitted);
        let decision = first.decision.expect("decision");
        assert_eq!(decision.expected_old_oid, BASE);
        assert_eq!(decision.candidate_oid, HEAD);
    }

    #[test]
    fn failed_status_wrong_bot_and_stale_canonical_are_denied() {
        let (event, mut result, _, receipt, mut live) = facts();
        result.disposition = RunnerDisposition::TimedOut;
        result.exit_code = None;
        assert!(!evaluate_canonical_guard(&policy(), &event, &result, &receipt, &live).admitted);

        let (event, result, _, receipt, mut live_again) = facts();
        live_again.status_author_did = DELEGATE_A.to_owned();
        assert!(
            !evaluate_canonical_guard(&policy(), &event, &result, &receipt, &live_again).admitted
        );

        live.current_canonical_oid = PATCH.to_owned();
        assert!(!evaluate_canonical_guard(&policy(), &event, &result, &receipt, &live).admitted);
    }

    #[test]
    fn duplicate_below_threshold_wrong_revision_and_tampered_receipt_are_denied() {
        let (event, result, _, mut receipt, mut live) = facts();
        live.approving_delegates = vec![DELEGATE_A.to_owned(), DELEGATE_A.to_owned()];
        assert!(!evaluate_canonical_guard(&policy(), &event, &result, &receipt, &live).admitted);

        let (_, _, _, _, mut below) = facts();
        below.approving_delegates = vec![DELEGATE_A.to_owned()];
        assert!(!evaluate_canonical_guard(&policy(), &event, &result, &receipt, &below).admitted);

        let (_, _, _, _, mut wrong_revision) = facts();
        wrong_revision.revision_id = PATCH.to_owned();
        assert!(
            !evaluate_canonical_guard(&policy(), &event, &result, &receipt, &wrong_revision)
                .admitted
        );

        let (_, _, _, _, live) = facts();
        receipt.candidate_oid = PATCH.to_owned();
        assert!(!evaluate_canonical_guard(&policy(), &event, &result, &receipt, &live).admitted);
    }

    #[test]
    fn non_descendant_weakened_policy_and_bot_delegate_are_denied() {
        let (event, result, _, receipt, mut live) = facts();
        live.candidate_is_descendant = false;
        assert!(!evaluate_canonical_guard(&policy(), &event, &result, &receipt, &live).admitted);

        let (_, _, _, _, mut unsigned) = facts();
        unsigned.signing_delegates.clear();
        assert!(
            !evaluate_canonical_guard(&policy(), &event, &result, &receipt, &unsigned).admitted
        );

        let (_, _, _, _, live) = facts();
        let mut weakened = policy();
        weakened.required_non_claims.clear();
        assert!(!evaluate_canonical_guard(&weakened, &event, &result, &receipt, &live).admitted);

        let mut delegated_bot = policy();
        delegated_bot.delegates = vec![BOT.to_owned(), DELEGATE_A.to_owned()];
        assert!(
            !evaluate_canonical_guard(&delegated_bot, &event, &result, &receipt, &live).admitted
        );
    }
}
