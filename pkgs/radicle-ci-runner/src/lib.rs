//! Pure admission and result classification for the Aspen1 Radicle CI runner.
//!
//! Filesystem, process, Radicle storage, clock, network, and credential effects
//! belong to the binary shell.

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

// r[impl onix.radicle_ci.admission]

pub const CONFIG_SCHEMA: &str = "onix.radicle-ci-runner.v1";
pub const EVENT_SCHEMA: &str = "onix.radicle-ci-event.v1";
pub const RESULT_SCHEMA: &str = "onix.radicle-ci-result.v1";
pub const RECEIPT_SCHEMA: &str = "onix.radicle-ci-deployment.v1";
pub const REQUIRED_SIGNED_REFS_FEATURE: &str = "parent";
pub const JOB_ID_DOMAIN: &str = "onix/radicle-ci/job/v1";
pub const BLAKE3_HEX_LENGTH: usize = 64;
pub const GIT_OID_HEX_LENGTH: usize = 40;
pub const MAX_TEXT_BYTES: usize = 1_024;
pub const MAX_ARGUMENT_COUNT: usize = 64;
pub const MAX_ALLOWED_INPUT_URIS: usize = 4;
pub const MAX_DELEGATE_COUNT: usize = 16;
pub const MAX_TIMEOUT_MS: u64 = 3_600_000;
pub const MAX_OUTPUT_BYTES: usize = 16 * 1_048_576;
pub const MAX_ARTIFACT_BYTES: u64 = 1_073_741_824;
pub const MAX_MEMORY_BYTES: u64 = 68_719_476_736;
pub const MAX_CPU_QUOTA_PERCENT: u64 = 800;
pub const MAX_PARALLEL_JOBS: u64 = 8;
pub const SUCCESS_EXIT_CODE: i32 = 0;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LockIdentityV1 {
    pub cargo_toml_blake3: String,
    pub cargo_lock_blake3: String,
    pub flake_nix_blake3: String,
    pub flake_lock_blake3: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RunnerLimitsV1 {
    pub timeout_ms: u64,
    pub stdin_max_bytes: usize,
    pub stdout_max_bytes: usize,
    pub stderr_max_bytes: usize,
    pub poll_interval_ms: u64,
    pub teardown_timeout_ms: u64,
    pub artifact_max_bytes: u64,
    pub memory_max_bytes: u64,
    pub cpu_quota_percent: u64,
    pub max_parallel_jobs: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RunnerConfigV1 {
    pub schema: String,
    pub rid: String,
    pub signed_refs_feature: String,
    pub production_seed: String,
    pub production_seed_node_id: String,
    pub production_seed_address: String,
    pub reviewed_commit: String,
    pub policy_blake3: String,
    pub bot_public_key: String,
    pub bot_node_id: String,
    pub bot_fingerprint: String,
    pub delegates: Vec<String>,
    pub expected_locks: LockIdentityV1,
    pub command_program: String,
    pub command_arguments: Vec<String>,
    pub allowed_input_uris: Vec<String>,
    pub git_program: String,
    pub nix_program: String,
    pub tar_program: String,
    pub rad_program: String,
    pub ssh_program: String,
    pub storage_path: String,
    pub bot_state_path: String,
    pub exchange_path: String,
    pub runner_state_path: String,
    pub artifact_path: String,
    pub local_store_root: String,
    pub limits: RunnerLimitsV1,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TriggerClass {
    Patch,
    CanonicalBranch,
    CanonicalTag,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CandidateV1 {
    pub rid: String,
    pub trigger: TriggerClass,
    pub reference: String,
    pub object_oid: String,
    pub patch_id: Option<String>,
    pub revision_id: Option<String>,
    pub object_present_locally: bool,
    pub object_is_current: bool,
    pub signed_refs_feature: String,
    pub delegate_alignment_verified: bool,
    pub observed_locks: LockIdentityV1,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdmittedEventV1 {
    pub schema: String,
    pub job_id: String,
    pub policy_blake3: String,
    pub rid: String,
    pub trigger: TriggerClass,
    pub reference: String,
    pub object_oid: String,
    pub patch_id: Option<String>,
    pub revision_id: Option<String>,
    pub signed_refs_feature: String,
    pub source_archive_blake3: String,
    pub locks: LockIdentityV1,
    pub claim_scope: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RunnerDisposition {
    Succeeded,
    ExitFailed,
    TimedOut,
    Cancelled,
    OutputLimitExceeded,
    InfrastructureFailed,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ObservationV1 {
    pub disposition: RunnerDisposition,
    pub exit_code: Option<i32>,
    pub stdout_observed_bytes: u64,
    pub stdout_retained_bytes: u64,
    pub stdout_blake3: String,
    pub stderr_observed_bytes: u64,
    pub stderr_retained_bytes: u64,
    pub stderr_blake3: String,
    pub artifact_bytes: u64,
    pub artifact_blake3: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct JobResultV1 {
    pub schema: String,
    pub job_id: String,
    pub rid: String,
    pub trigger: TriggerClass,
    pub object_oid: String,
    pub patch_id: Option<String>,
    pub revision_id: Option<String>,
    pub disposition: RunnerDisposition,
    pub exit_code: Option<i32>,
    pub stdout_observed_bytes: u64,
    pub stdout_retained_bytes: u64,
    pub stdout_blake3: String,
    pub stderr_observed_bytes: u64,
    pub stderr_retained_bytes: u64,
    pub stderr_blake3: String,
    pub artifact_bytes: u64,
    pub artifact_blake3: String,
    pub status_authority: String,
    pub claim_scope: String,
    pub non_claims: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Diagnostic {
    pub code: &'static str,
    pub message: &'static str,
}

impl std::fmt::Display for Diagnostic {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(formatter, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for Diagnostic {}

/// Validate deployment configuration without observing the host.
///
/// # Errors
/// Returns the first stable policy diagnostic.
pub fn validate_config(config: &RunnerConfigV1) -> Result<(), Diagnostic> {
    if config.schema != CONFIG_SCHEMA
        || !radicle_id(&config.rid)
        || config.signed_refs_feature != REQUIRED_SIGNED_REFS_FEATURE
    {
        return Err(diagnostic(
            "ci-config-header",
            "configuration schema, RID, or signed-reference feature is invalid",
        ));
    }
    if !git_oid(&config.reviewed_commit)
        || !blake3_digest(&config.policy_blake3)
        || !config
            .production_seed
            .starts_with(&config.production_seed_node_id)
        || !config
            .production_seed
            .ends_with(&config.production_seed_address)
        || config.production_seed_node_id == config.bot_node_id
        || config
            .delegates
            .iter()
            .any(|delegate| delegate.ends_with(&config.bot_node_id))
    {
        return Err(diagnostic(
            "ci-config-identity",
            "reviewed source, seed, bot, or delegate identity is invalid",
        ));
    }
    if config.delegates.is_empty()
        || config.delegates.len() > MAX_DELEGATE_COUNT
        || config.bot_public_key.split_whitespace().count() != 2
        || !config.bot_public_key.starts_with("ssh-ed25519 ")
        || !config.bot_fingerprint.starts_with("SHA256:")
    {
        return Err(diagnostic(
            "ci-config-bot",
            "bot public identity or delegate policy is malformed",
        ));
    }
    validate_locks(&config.expected_locks)?;
    validate_limits(&config.limits)?;
    if !absolute_path(&config.command_program)
        || !absolute_path(&config.git_program)
        || !absolute_path(&config.nix_program)
        || !absolute_path(&config.tar_program)
        || !absolute_path(&config.rad_program)
        || !absolute_path(&config.ssh_program)
        || config.command_program != config.nix_program
        || config.command_arguments.is_empty()
        || config.command_arguments.len() > MAX_ARGUMENT_COUNT
        || config
            .command_arguments
            .iter()
            .any(|argument| argument.is_empty() || argument.len() > MAX_TEXT_BYTES)
        || !config
            .command_arguments
            .iter()
            .any(|argument| argument == "--no-update-lock-file")
    {
        return Err(diagnostic(
            "ci-config-command",
            "runner command or executable path is invalid",
        ));
    }
    if config.allowed_input_uris.is_empty()
        || config.allowed_input_uris.len() > MAX_ALLOWED_INPUT_URIS
        || config.allowed_input_uris.iter().any(|uri| {
            !uri.starts_with("github:")
                || uri.len() > MAX_TEXT_BYTES
                || uri.chars().any(char::is_whitespace)
        })
    {
        return Err(diagnostic(
            "ci-config-input-uris",
            "restricted evaluation input URI allowlist is invalid",
        ));
    }
    for path in [
        &config.storage_path,
        &config.bot_state_path,
        &config.exchange_path,
        &config.runner_state_path,
        &config.artifact_path,
        &config.local_store_root,
    ] {
        if !absolute_path(path) {
            return Err(diagnostic(
                "ci-config-path",
                "runner state paths must be absolute",
            ));
        }
    }
    Ok(())
}

/// Admit a current exact object under the configured policy.
///
/// # Errors
/// Returns a stable rejection when any source or authority fact drifts.
pub fn admit_candidate(
    config: &RunnerConfigV1,
    candidate: &CandidateV1,
    source_archive_blake3: &str,
) -> Result<AdmittedEventV1, Diagnostic> {
    validate_config(config)?;
    if candidate.rid != config.rid
        || !git_oid(&candidate.object_oid)
        || !candidate.object_present_locally
        || !candidate.object_is_current
        || candidate.signed_refs_feature != config.signed_refs_feature
        || !candidate.delegate_alignment_verified
    {
        return Err(diagnostic(
            "ci-candidate-source",
            "candidate is not the current admitted local Radicle object",
        ));
    }
    validate_trigger(candidate)?;
    if candidate.observed_locks != config.expected_locks {
        return Err(diagnostic(
            "ci-candidate-locks",
            "candidate changed an admitted Cargo or Nix control file",
        ));
    }
    if !blake3_digest(source_archive_blake3) {
        return Err(diagnostic(
            "ci-candidate-archive",
            "source archive BLAKE3 is malformed",
        ));
    }
    let job_id = derive_job_id(config, candidate, source_archive_blake3)?;
    Ok(AdmittedEventV1 {
        schema: EVENT_SCHEMA.to_string(),
        job_id,
        policy_blake3: config.policy_blake3.clone(),
        rid: candidate.rid.clone(),
        trigger: candidate.trigger,
        reference: candidate.reference.clone(),
        object_oid: candidate.object_oid.clone(),
        patch_id: candidate.patch_id.clone(),
        revision_id: candidate.revision_id.clone(),
        signed_refs_feature: candidate.signed_refs_feature.clone(),
        source_archive_blake3: source_archive_blake3.to_string(),
        locks: candidate.observed_locks.clone(),
        claim_scope: "exact-object-bounded-ci-input".to_string(),
    })
}

/// Revalidate a persisted event before execution.
///
/// # Errors
/// Returns a stable diagnostic if the spool was altered.
pub fn validate_event(config: &RunnerConfigV1, event: &AdmittedEventV1) -> Result<(), Diagnostic> {
    validate_config(config)?;
    if event.schema != EVENT_SCHEMA
        || event.policy_blake3 != config.policy_blake3
        || event.rid != config.rid
        || !git_oid(&event.object_oid)
        || !blake3_digest(&event.source_archive_blake3)
        || event.signed_refs_feature != config.signed_refs_feature
        || event.locks != config.expected_locks
        || event.claim_scope != "exact-object-bounded-ci-input"
    {
        return Err(diagnostic(
            "ci-event-shape",
            "persisted event does not match the admitted policy",
        ));
    }
    let candidate = CandidateV1 {
        rid: event.rid.clone(),
        trigger: event.trigger,
        reference: event.reference.clone(),
        object_oid: event.object_oid.clone(),
        patch_id: event.patch_id.clone(),
        revision_id: event.revision_id.clone(),
        object_present_locally: true,
        object_is_current: true,
        signed_refs_feature: event.signed_refs_feature.clone(),
        delegate_alignment_verified: true,
        observed_locks: event.locks.clone(),
    };
    validate_trigger(&candidate)?;
    let expected = derive_job_id(config, &candidate, &event.source_archive_blake3)?;
    if event.job_id != expected {
        return Err(diagnostic(
            "ci-event-job-id",
            "persisted event job identity does not match its facts",
        ));
    }
    Ok(())
}

/// Classify one bounded process observation under the admitted event.
///
/// # Errors
/// Returns a stable diagnostic for malformed or over-limit observations.
pub fn classify_observation(
    config: &RunnerConfigV1,
    event: &AdmittedEventV1,
    observation: &ObservationV1,
) -> Result<JobResultV1, Diagnostic> {
    validate_event(config, event)?;
    if !blake3_digest(&observation.stdout_blake3)
        || !blake3_digest(&observation.stderr_blake3)
        || !blake3_digest(&observation.artifact_blake3)
        || observation.stdout_retained_bytes > config.limits.stdout_max_bytes as u64
        || observation.stderr_retained_bytes > config.limits.stderr_max_bytes as u64
        || observation.stdout_retained_bytes > observation.stdout_observed_bytes
        || observation.stderr_retained_bytes > observation.stderr_observed_bytes
        || observation.artifact_bytes > config.limits.artifact_max_bytes
        || (observation.disposition == RunnerDisposition::Succeeded
            && observation.exit_code != Some(SUCCESS_EXIT_CODE))
    {
        return Err(diagnostic(
            "ci-observation-bounds",
            "runner observation is malformed or above configured limits",
        ));
    }
    Ok(JobResultV1 {
        schema: RESULT_SCHEMA.to_string(),
        job_id: event.job_id.clone(),
        rid: event.rid.clone(),
        trigger: event.trigger,
        object_oid: event.object_oid.clone(),
        patch_id: event.patch_id.clone(),
        revision_id: event.revision_id.clone(),
        disposition: observation.disposition,
        exit_code: observation.exit_code,
        stdout_observed_bytes: observation.stdout_observed_bytes,
        stdout_retained_bytes: observation.stdout_retained_bytes,
        stdout_blake3: observation.stdout_blake3.clone(),
        stderr_observed_bytes: observation.stderr_observed_bytes,
        stderr_retained_bytes: observation.stderr_retained_bytes,
        stderr_blake3: observation.stderr_blake3.clone(),
        artifact_bytes: observation.artifact_bytes,
        artifact_blake3: observation.artifact_blake3.clone(),
        status_authority: "non-delegate-patch-comment-only".to_string(),
        claim_scope: "bounded-ci-observation".to_string(),
        non_claims: required_non_claims(),
    })
}

/// Validate a result before status publication.
///
/// # Errors
/// Returns a stable diagnostic for a result that does not preserve event facts.
pub fn validate_result(event: &AdmittedEventV1, result: &JobResultV1) -> Result<(), Diagnostic> {
    if result.schema != RESULT_SCHEMA
        || result.job_id != event.job_id
        || result.rid != event.rid
        || result.trigger != event.trigger
        || result.object_oid != event.object_oid
        || result.patch_id != event.patch_id
        || result.revision_id != event.revision_id
        || !blake3_digest(&result.stdout_blake3)
        || !blake3_digest(&result.stderr_blake3)
        || !blake3_digest(&result.artifact_blake3)
        || result.status_authority != "non-delegate-patch-comment-only"
        || result.claim_scope != "bounded-ci-observation"
        || result.non_claims != required_non_claims()
    {
        return Err(diagnostic(
            "ci-result-shape",
            "job result does not preserve the admitted event and claim boundary",
        ));
    }
    Ok(())
}

/// Return the fixed deployment non-claims in deterministic order.
#[must_use]
pub fn required_non_claims() -> Vec<String> {
    [
        "ci-result-does-not-prove-source-correctness",
        "ci-result-does-not-prove-nix-correctness",
        "ci-result-does-not-prove-host-sandboxing",
        "ci-result-does-not-prove-canonical-ref-authority",
        "ci-result-does-not-prove-release-readiness",
        "artifact-publication-does-not-prove-remote-durability",
        "status-publication-does-not-prove-merge-eligibility",
        "bot-replication-does-not-grant-production-seed-policy-authority",
    ]
    .into_iter()
    .map(str::to_string)
    .collect()
}

fn validate_trigger(candidate: &CandidateV1) -> Result<(), Diagnostic> {
    if candidate.reference.is_empty() || candidate.reference.len() > MAX_TEXT_BYTES {
        return Err(diagnostic(
            "ci-candidate-reference",
            "candidate reference is empty or too long",
        ));
    }
    match candidate.trigger {
        TriggerClass::Patch => {
            if candidate.patch_id.as_deref().is_none_or(str::is_empty)
                || candidate.revision_id.as_deref().is_none_or(str::is_empty)
                || !candidate.reference.contains("refs/cobs/xyz.radicle.patch/")
            {
                return Err(diagnostic(
                    "ci-candidate-patch",
                    "patch candidate lacks exact patch and revision linkage",
                ));
            }
        }
        TriggerClass::CanonicalBranch => {
            if candidate.patch_id.is_some()
                || candidate.revision_id.is_some()
                || candidate.reference != "refs/heads/main"
            {
                return Err(diagnostic(
                    "ci-candidate-branch",
                    "canonical branch candidate is malformed",
                ));
            }
        }
        TriggerClass::CanonicalTag => {
            if candidate.patch_id.is_some()
                || candidate.revision_id.is_some()
                || !candidate.reference.starts_with("refs/tags/")
            {
                return Err(diagnostic(
                    "ci-candidate-tag",
                    "canonical tag candidate is malformed",
                ));
            }
        }
    }
    Ok(())
}

fn validate_locks(locks: &LockIdentityV1) -> Result<(), Diagnostic> {
    if [
        &locks.cargo_toml_blake3,
        &locks.cargo_lock_blake3,
        &locks.flake_nix_blake3,
        &locks.flake_lock_blake3,
    ]
    .into_iter()
    .any(|digest| !blake3_digest(digest))
    {
        return Err(diagnostic(
            "ci-config-locks",
            "expected source-control BLAKE3 identities are malformed",
        ));
    }
    Ok(())
}

fn validate_limits(limits: &RunnerLimitsV1) -> Result<(), Diagnostic> {
    if limits.timeout_ms == 0
        || limits.timeout_ms > MAX_TIMEOUT_MS
        || limits.stdin_max_bytes == 0
        || limits.stdout_max_bytes == 0
        || limits.stdout_max_bytes > MAX_OUTPUT_BYTES
        || limits.stderr_max_bytes == 0
        || limits.stderr_max_bytes > MAX_OUTPUT_BYTES
        || limits.poll_interval_ms == 0
        || limits.poll_interval_ms > limits.timeout_ms
        || limits.teardown_timeout_ms == 0
        || limits.artifact_max_bytes == 0
        || limits.artifact_max_bytes > MAX_ARTIFACT_BYTES
        || limits.memory_max_bytes == 0
        || limits.memory_max_bytes > MAX_MEMORY_BYTES
        || limits.cpu_quota_percent == 0
        || limits.cpu_quota_percent > MAX_CPU_QUOTA_PERCENT
        || limits.max_parallel_jobs == 0
        || limits.max_parallel_jobs > MAX_PARALLEL_JOBS
    {
        return Err(diagnostic(
            "ci-config-limits",
            "runner limits are zero, inconsistent, or above hard maxima",
        ));
    }
    Ok(())
}

fn derive_job_id(
    config: &RunnerConfigV1,
    candidate: &CandidateV1,
    source_archive_blake3: &str,
) -> Result<String, Diagnostic> {
    let facts = serde_json::to_vec(&(
        JOB_ID_DOMAIN,
        &config.policy_blake3,
        &candidate.rid,
        candidate.trigger,
        &candidate.reference,
        &candidate.object_oid,
        &candidate.patch_id,
        &candidate.revision_id,
        source_archive_blake3,
        &candidate.observed_locks,
    ))
    .map_err(|_| diagnostic("ci-job-id", "job identity facts could not be serialized"))?;
    Ok(blake3::hash(&facts).to_hex().to_string())
}

fn absolute_path(value: &str) -> bool {
    value.starts_with('/') && value.len() <= MAX_TEXT_BYTES && !value.contains('\0')
}

fn radicle_id(value: &str) -> bool {
    value.starts_with("rad:z") && value.len() <= MAX_TEXT_BYTES
}

fn git_oid(value: &str) -> bool {
    value.len() == GIT_OID_HEX_LENGTH
        && value
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
}

fn blake3_digest(value: &str) -> bool {
    value.len() == BLAKE3_HEX_LENGTH
        && value
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
}

const fn diagnostic(code: &'static str, message: &'static str) -> Diagnostic {
    Diagnostic { code, message }
}

#[cfg(test)]
mod tests {
    use super::*;

    const RID: &str = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
    const OID: &str = "29dac88ecded94457572db3fdfaaaab95fa91525";
    const DIGEST_A: &str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const DIGEST_B: &str = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    const BOT_NID: &str = "z6Mbotbotbotbotbotbotbotbotbotbotbotbotbotbotbotbot";
    const SEED_NID: &str = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8";
    const TIMEOUT_MS: u64 = 900_000;
    const STDIN_BYTES: usize = 1;
    const OUTPUT_BYTES: usize = 1_048_576;
    const POLL_MS: u64 = 25;
    const TEARDOWN_MS: u64 = 5_000;
    const ARTIFACT_BYTES: u64 = 67_108_864;
    const MEMORY_BYTES: u64 = 8_589_934_592;
    const CPU_PERCENT: u64 = 200;
    const PARALLEL_JOBS: u64 = 1;

    fn locks() -> LockIdentityV1 {
        LockIdentityV1 {
            cargo_toml_blake3: DIGEST_A.to_string(),
            cargo_lock_blake3: DIGEST_A.to_string(),
            flake_nix_blake3: DIGEST_A.to_string(),
            flake_lock_blake3: DIGEST_A.to_string(),
        }
    }

    fn config() -> RunnerConfigV1 {
        RunnerConfigV1 {
            schema: CONFIG_SCHEMA.to_string(),
            rid: RID.to_string(),
            signed_refs_feature: REQUIRED_SIGNED_REFS_FEATURE.to_string(),
            production_seed: format!("{SEED_NID}@100.100.103.95:8776"),
            production_seed_node_id: SEED_NID.to_string(),
            production_seed_address: "100.100.103.95:8776".to_string(),
            reviewed_commit: OID.to_string(),
            policy_blake3: DIGEST_A.to_string(),
            bot_public_key:
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                    .to_string(),
            bot_node_id: BOT_NID.to_string(),
            bot_fingerprint: "SHA256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".to_string(),
            delegates: vec!["did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx".to_string()],
            expected_locks: locks(),
            command_program: "/nix/store/nix/bin/nix".to_string(),
            command_arguments: vec!["build".to_string(), "--no-update-lock-file".to_string()],
            allowed_input_uris: vec![
                "github:NixOS/nixpkgs/61b7c44c4073f0b827768aff0049561b5110ea5a".to_string(),
                "github:oxalica/rust-overlay/3c38e1e1ba9c8d7030f7b5a801398ea7d8a6fdc0".to_string(),
            ],
            git_program: "/nix/store/git/bin/git".to_string(),
            nix_program: "/nix/store/nix/bin/nix".to_string(),
            tar_program: "/nix/store/tar/bin/tar".to_string(),
            rad_program: "/nix/store/radicle/bin/rad".to_string(),
            ssh_program: "/nix/store/openssh/bin/ssh".to_string(),
            storage_path: "/var/lib/radicle-ci-bot/storage".to_string(),
            bot_state_path: "/var/lib/radicle-ci-bot".to_string(),
            exchange_path: "/var/lib/radicle-ci-exchange".to_string(),
            runner_state_path: "/var/lib/radicle-ci-runner".to_string(),
            artifact_path: "/var/lib/radicle-ci-artifacts".to_string(),
            local_store_root: "/var/lib/radicle-ci-runner/local-store".to_string(),
            limits: RunnerLimitsV1 {
                timeout_ms: TIMEOUT_MS,
                stdin_max_bytes: STDIN_BYTES,
                stdout_max_bytes: OUTPUT_BYTES,
                stderr_max_bytes: OUTPUT_BYTES,
                poll_interval_ms: POLL_MS,
                teardown_timeout_ms: TEARDOWN_MS,
                artifact_max_bytes: ARTIFACT_BYTES,
                memory_max_bytes: MEMORY_BYTES,
                cpu_quota_percent: CPU_PERCENT,
                max_parallel_jobs: PARALLEL_JOBS,
            },
        }
    }

    fn patch_candidate() -> CandidateV1 {
        CandidateV1 {
            rid: RID.to_string(),
            trigger: TriggerClass::Patch,
            reference: "refs/namespaces/z6Mauthor/refs/cobs/xyz.radicle.patch/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".to_string(),
            object_oid: OID.to_string(),
            patch_id: Some("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".to_string()),
            revision_id: Some("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".to_string()),
            object_present_locally: true,
            object_is_current: true,
            signed_refs_feature: REQUIRED_SIGNED_REFS_FEATURE.to_string(),
            delegate_alignment_verified: true,
            observed_locks: locks(),
        }
    }

    fn observation() -> ObservationV1 {
        ObservationV1 {
            disposition: RunnerDisposition::Succeeded,
            exit_code: Some(SUCCESS_EXIT_CODE),
            stdout_observed_bytes: 1,
            stdout_retained_bytes: 1,
            stdout_blake3: DIGEST_A.to_string(),
            stderr_observed_bytes: 0,
            stderr_retained_bytes: 0,
            stderr_blake3: DIGEST_A.to_string(),
            artifact_bytes: 1,
            artifact_blake3: DIGEST_A.to_string(),
        }
    }

    #[test]
    fn admits_exact_patch_deterministically_and_classifies_success() {
        let config = config();
        let candidate = patch_candidate();
        let first = admit_candidate(&config, &candidate, DIGEST_A).expect("exact patch admitted");
        let second = admit_candidate(&config, &candidate, DIGEST_A).expect("repeat admitted");
        assert_eq!(first, second);
        assert_eq!(validate_event(&config, &first), Ok(()));
        let result = classify_observation(&config, &first, &observation()).expect("classified");
        assert_eq!(result.disposition, RunnerDisposition::Succeeded);
        assert_eq!(validate_result(&first, &result), Ok(()));
    }

    #[test]
    fn rejects_wrong_rid_stale_object_changed_locks_and_archive() {
        let config = config();
        let mut wrong_rid = patch_candidate();
        wrong_rid.rid = "rad:zWrong".to_string();
        assert_eq!(
            admit_candidate(&config, &wrong_rid, DIGEST_A)
                .unwrap_err()
                .code,
            "ci-candidate-source"
        );

        let mut stale = patch_candidate();
        stale.object_is_current = false;
        assert_eq!(
            admit_candidate(&config, &stale, DIGEST_A).unwrap_err().code,
            "ci-candidate-source"
        );

        let mut changed = patch_candidate();
        changed.observed_locks.flake_lock_blake3 = DIGEST_B.to_string();
        assert_eq!(
            admit_candidate(&config, &changed, DIGEST_A)
                .unwrap_err()
                .code,
            "ci-candidate-locks"
        );
        assert_eq!(
            admit_candidate(&config, &patch_candidate(), "bad")
                .unwrap_err()
                .code,
            "ci-candidate-archive"
        );
    }

    #[test]
    fn rejects_bot_delegate_expanded_limits_and_malformed_patch() {
        let mut delegated = config();
        delegated.delegates.push(format!("did:key:{BOT_NID}"));
        assert_eq!(
            validate_config(&delegated).unwrap_err().code,
            "ci-config-identity"
        );

        let mut unbounded = config();
        unbounded.limits.timeout_ms = MAX_TIMEOUT_MS + 1;
        assert_eq!(
            validate_config(&unbounded).unwrap_err().code,
            "ci-config-limits"
        );

        let mut malformed = patch_candidate();
        malformed.revision_id = None;
        assert_eq!(
            admit_candidate(&config(), &malformed, DIGEST_A)
                .unwrap_err()
                .code,
            "ci-candidate-patch"
        );
    }

    #[test]
    fn rejects_tampered_event_and_over_limit_observation() {
        let config = config();
        let event = admit_candidate(&config, &patch_candidate(), DIGEST_A).expect("admitted");
        let mut tampered = event.clone();
        tampered.object_oid = "1111111111111111111111111111111111111111".to_string();
        assert_eq!(
            validate_event(&config, &tampered).unwrap_err().code,
            "ci-event-job-id"
        );

        let mut excessive = observation();
        excessive.stdout_retained_bytes = u64::try_from(OUTPUT_BYTES).expect("bound fits") + 1;
        assert_eq!(
            classify_observation(&config, &event, &excessive)
                .unwrap_err()
                .code,
            "ci-observation-bounds"
        );
    }

    #[test]
    fn preserves_timeout_and_output_flood_as_explicit_results() {
        let config = config();
        let event = admit_candidate(&config, &patch_candidate(), DIGEST_A).expect("admitted");
        let mut timed_out = observation();
        timed_out.disposition = RunnerDisposition::TimedOut;
        timed_out.exit_code = None;
        let timeout_result =
            classify_observation(&config, &event, &timed_out).expect("timeout classified");
        assert_eq!(timeout_result.disposition, RunnerDisposition::TimedOut);

        let mut flooded = observation();
        flooded.disposition = RunnerDisposition::OutputLimitExceeded;
        flooded.exit_code = None;
        flooded.stdout_observed_bytes = u64::try_from(OUTPUT_BYTES).expect("bound fits") + 1;
        flooded.stdout_retained_bytes = u64::try_from(OUTPUT_BYTES).expect("bound fits");
        let flood_result =
            classify_observation(&config, &event, &flooded).expect("flood classified");
        assert_eq!(
            flood_result.disposition,
            RunnerDisposition::OutputLimitExceeded
        );
    }

    #[test]
    fn rejects_command_weakening_artifact_overflow_and_result_tampering() {
        let mut weakened = config();
        weakened
            .command_arguments
            .retain(|argument| argument != "--no-update-lock-file");
        assert_eq!(
            validate_config(&weakened).unwrap_err().code,
            "ci-config-command"
        );
        weakened = config();
        weakened.allowed_input_uris = vec!["https://unbounded.example/input".to_string()];
        assert_eq!(
            validate_config(&weakened).unwrap_err().code,
            "ci-config-input-uris"
        );

        let config = config();
        let event = admit_candidate(&config, &patch_candidate(), DIGEST_A).expect("admitted");
        let mut oversized = observation();
        oversized.artifact_bytes = ARTIFACT_BYTES + 1;
        assert_eq!(
            classify_observation(&config, &event, &oversized)
                .unwrap_err()
                .code,
            "ci-observation-bounds"
        );

        let mut result = classify_observation(&config, &event, &observation()).expect("classified");
        result.status_authority = "canonical-ref-write".to_string();
        assert_eq!(
            validate_result(&event, &result).unwrap_err().code,
            "ci-result-shape"
        );
    }

    #[test]
    fn admits_exact_canonical_head_and_rejects_malformed_tag() {
        let config = config();
        let mut canonical = patch_candidate();
        canonical.trigger = TriggerClass::CanonicalBranch;
        canonical.reference = "refs/heads/main".to_string();
        canonical.patch_id = None;
        canonical.revision_id = None;
        assert!(admit_candidate(&config, &canonical, DIGEST_A).is_ok());

        canonical.trigger = TriggerClass::CanonicalTag;
        assert_eq!(
            admit_candidate(&config, &canonical, DIGEST_A)
                .unwrap_err()
                .code,
            "ci-candidate-tag"
        );
    }
}
