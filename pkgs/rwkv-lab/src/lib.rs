use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::path::Path;

pub const MANIFEST_SCHEMA_VERSION: u32 = 1;
pub const EVIDENCE_SCHEMA_VERSION: u32 = 1;
pub const RECEIPT_SCHEMA_VERSION: u32 = 1;
const SINGLE_PROCESS_BUDGET: u32 = 1;
const MINIMUM_HTTP_STATUS: u16 = 100;
const MAXIMUM_HTTP_STATUS: u16 = 599;
const BLAKE3_HEX_LENGTH: usize = 64;
const ADJACENT_PAIR_WIDTH: usize = 2;
const NIX_STORE_PREFIX: &str = "/nix/store/";
const TENSTORRENT_DEVICE_PREFIX: &str = "/dev/tenstorrent/";
const LOOPBACK_ADDRESS_PREFIX: &str = "127.0.0.1:";
const LOOPBACK_HTTP_PREFIX: &str = "http://127.0.0.1:";

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.session_receipts]
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct SessionManifest {
    pub schema_version: u32,
    pub session_id: String,
    pub stage: Stage,
    pub target: Target,
    pub hardware: Hardware,
    pub runtime: RuntimeState,
    pub budget: Budget,
    pub restoration: Restoration,
    pub evidence: EvidenceExpectations,
    pub claims: Claims,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Stage {
    DataMovement,
    Operator,
    Layer,
    Token,
    StatefulDecode,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Target {
    pub package_path: String,
    pub kernel_path: String,
    pub executable: String,
    pub arguments: Vec<String>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Hardware {
    pub architecture: String,
    pub physical_device: u32,
    pub device_path: String,
    pub owner_unit: String,
    pub owner_control_path: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct RuntimeState {
    pub run_root: String,
    pub cache_path: String,
    pub logs_path: String,
    pub inspector_address: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Budget {
    pub max_processes: u32,
    pub timeout_seconds: u64,
    pub timeout_exit_status: u16,
    pub kill_grace_seconds: u64,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Restoration {
    pub rollback_delay_seconds: u64,
    pub health_url: String,
    pub expected_health_status: u16,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct EvidenceExpectations {
    pub required_artifact_roles: Vec<String>,
    pub success_markers: Vec<String>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Claims {
    pub success: String,
    pub non_claims: Vec<String>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct PlanReceipt {
    pub schema_version: u32,
    pub plan_id: String,
    pub plan: SessionManifest,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct SessionEvidence {
    pub schema_version: u32,
    pub plan_id: String,
    pub process_attempts: u32,
    pub owner_isolation_attempts: u32,
    pub restoration_attempts: u32,
    pub process: Option<ProcessResult>,
    pub owner_active_after: Option<bool>,
    pub owner_health_status_after: Option<u16>,
    pub board_healthy_after: Option<bool>,
    pub artifacts: Vec<ArtifactEvidence>,
    pub observed_markers: Vec<String>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ProcessResult {
    pub exit_status: u16,
    pub timed_out: bool,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ArtifactEvidence {
    pub role: String,
    pub blake3: String,
    pub bytes: u64,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Outcome {
    NotRun,
    Blocked,
    Passed,
    Failed,
    PartialDiagnostic,
    Unsafe,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct ClassificationReceipt {
    pub schema_version: u32,
    pub plan_id: String,
    pub outcome: Outcome,
    pub process_budget_exhausted: bool,
    pub missing_artifact_roles: Vec<String>,
    pub missing_success_markers: Vec<String>,
    pub safety_issues: Vec<String>,
    pub success_claim: Option<String>,
    pub non_claims: Vec<String>,
}

pub fn validate_manifest(manifest: &SessionManifest) -> Result<(), String> {
    if manifest.schema_version != MANIFEST_SCHEMA_VERSION {
        return Err(format!(
            "manifest schema_version must be {MANIFEST_SCHEMA_VERSION}"
        ));
    }
    validate_session_id(&manifest.session_id)?;
    validate_store_path(&manifest.target.package_path, "target.package_path")?;
    validate_store_path(&manifest.target.kernel_path, "target.kernel_path")?;
    validate_store_path(&manifest.target.executable, "target.executable")?;
    validate_store_path(
        &manifest.hardware.owner_control_path,
        "hardware.owner_control_path",
    )?;
    validate_canonical_text(&manifest.hardware.architecture, "hardware.architecture")?;
    validate_canonical_text(&manifest.hardware.owner_unit, "hardware.owner_unit")?;
    if !manifest.hardware.owner_unit.ends_with(".service") {
        return Err("hardware.owner_unit must name an exact .service unit".to_owned());
    }

    let package_prefix = format!("{}/", manifest.target.package_path.trim_end_matches('/'));
    if !manifest.target.executable.starts_with(&package_prefix) {
        return Err("target.executable must be contained by target.package_path".to_owned());
    }
    for argument in &manifest.target.arguments {
        validate_canonical_text(argument, "target.arguments entry")?;
    }

    let expected_device_path = format!(
        "{TENSTORRENT_DEVICE_PREFIX}{}",
        manifest.hardware.physical_device
    );
    if manifest.hardware.device_path != expected_device_path {
        return Err(format!(
            "hardware.device_path must equal {expected_device_path}"
        ));
    }

    for (path, name) in [
        (&manifest.runtime.run_root, "runtime.run_root"),
        (&manifest.runtime.cache_path, "runtime.cache_path"),
        (&manifest.runtime.logs_path, "runtime.logs_path"),
    ] {
        validate_runtime_path(path, name)?;
    }
    if manifest.runtime.cache_path == manifest.runtime.logs_path {
        return Err("runtime.cache_path and runtime.logs_path must differ".to_owned());
    }
    let run_root_prefix = format!("{}/", manifest.runtime.run_root.trim_end_matches('/'));
    for (path, name) in [
        (&manifest.runtime.cache_path, "runtime.cache_path"),
        (&manifest.runtime.logs_path, "runtime.logs_path"),
    ] {
        if !path.starts_with(&run_root_prefix) {
            return Err(format!("{name} must be contained by runtime.run_root"));
        }
    }
    validate_loopback_address(&manifest.runtime.inspector_address)?;

    if manifest.budget.max_processes != SINGLE_PROCESS_BUDGET {
        return Err(format!(
            "budget.max_processes must equal {SINGLE_PROCESS_BUDGET}"
        ));
    }
    if manifest.budget.timeout_seconds == 0 {
        return Err("budget.timeout_seconds must be positive".to_owned());
    }
    if manifest.budget.timeout_exit_status == 0 {
        return Err("budget.timeout_exit_status must be positive".to_owned());
    }
    if manifest.budget.kill_grace_seconds == 0 {
        return Err("budget.kill_grace_seconds must be positive".to_owned());
    }
    let process_deadline = manifest
        .budget
        .timeout_seconds
        .checked_add(manifest.budget.kill_grace_seconds)
        .ok_or_else(|| "process deadline overflows u64".to_owned())?;
    if manifest.restoration.rollback_delay_seconds <= process_deadline {
        return Err(
            "restoration.rollback_delay_seconds must exceed timeout plus kill grace".to_owned(),
        );
    }
    validate_loopback_health_url(&manifest.restoration.health_url)?;
    if !(MINIMUM_HTTP_STATUS..=MAXIMUM_HTTP_STATUS)
        .contains(&manifest.restoration.expected_health_status)
    {
        return Err(format!(
            "restoration.expected_health_status must be between {MINIMUM_HTTP_STATUS} and {MAXIMUM_HTTP_STATUS}"
        ));
    }

    validate_sorted_unique_nonempty(
        &manifest.evidence.required_artifact_roles,
        "evidence.required_artifact_roles",
    )?;
    validate_sorted_unique_nonempty(
        &manifest.evidence.success_markers,
        "evidence.success_markers",
    )?;
    validate_canonical_text(&manifest.claims.success, "claims.success")?;
    validate_sorted_unique_nonempty(&manifest.claims.non_claims, "claims.non_claims")?;
    Ok(())
}

pub fn plan_id(manifest: &SessionManifest) -> Result<String, String> {
    validate_manifest(manifest)?;
    let canonical = serde_json::to_vec(manifest)
        .map_err(|error| format!("failed to serialize normalized manifest: {error}"))?;
    Ok(blake3::hash(&canonical).to_hex().to_string())
}

pub fn plan_receipt(manifest: SessionManifest) -> Result<PlanReceipt, String> {
    let identifier = plan_id(&manifest)?;
    Ok(PlanReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION,
        plan_id: identifier,
        plan: manifest,
    })
}

pub fn classify(
    manifest: &SessionManifest,
    evidence: &SessionEvidence,
) -> Result<ClassificationReceipt, String> {
    let identifier = plan_id(manifest)?;
    validate_evidence_shape(evidence)?;
    if evidence.schema_version != EVIDENCE_SCHEMA_VERSION {
        return Err(format!(
            "evidence schema_version must be {EVIDENCE_SCHEMA_VERSION}"
        ));
    }
    if evidence.plan_id != identifier {
        return Err("evidence plan_id does not match the validated manifest".to_owned());
    }

    let mut safety_issues = safety_issues(manifest, evidence);
    safety_issues.sort();
    let artifact_roles: BTreeSet<&str> = evidence
        .artifacts
        .iter()
        .map(|artifact| artifact.role.as_str())
        .collect();
    let observed_markers: BTreeSet<&str> = evidence
        .observed_markers
        .iter()
        .map(String::as_str)
        .collect();
    let missing_artifact_roles = manifest
        .evidence
        .required_artifact_roles
        .iter()
        .filter(|role| !artifact_roles.contains(role.as_str()))
        .cloned()
        .collect::<Vec<_>>();
    let missing_success_markers = manifest
        .evidence
        .success_markers
        .iter()
        .filter(|marker| !observed_markers.contains(marker.as_str()))
        .cloned()
        .collect::<Vec<_>>();

    let outcome = if !safety_issues.is_empty() {
        Outcome::Unsafe
    } else if evidence.process_attempts == 0 && evidence.owner_isolation_attempts == 0 {
        Outcome::NotRun
    } else if evidence.process_attempts == 0 {
        Outcome::Blocked
    } else if !missing_artifact_roles.is_empty() {
        Outcome::PartialDiagnostic
    } else {
        let process = evidence
            .process
            .as_ref()
            .ok_or_else(|| "validated process evidence unexpectedly missing".to_owned())?;
        if process.exit_status == 0 && !process.timed_out && missing_success_markers.is_empty() {
            Outcome::Passed
        } else {
            Outcome::Failed
        }
    };
    let success_claim = (outcome == Outcome::Passed).then(|| manifest.claims.success.clone());

    Ok(ClassificationReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION,
        plan_id: identifier,
        outcome,
        process_budget_exhausted: evidence.process_attempts >= manifest.budget.max_processes,
        missing_artifact_roles,
        missing_success_markers,
        safety_issues,
        success_claim,
        non_claims: manifest.claims.non_claims.clone(),
    })
}

fn validate_session_id(session_id: &str) -> Result<(), String> {
    validate_canonical_text(session_id, "session_id")?;
    let valid = session_id
        .bytes()
        .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-');
    if !valid || session_id.starts_with('-') || session_id.ends_with('-') {
        return Err(
            "session_id must be a lowercase alphanumeric slug with internal hyphens".to_owned(),
        );
    }
    Ok(())
}

fn validate_store_path(path: &str, name: &str) -> Result<(), String> {
    validate_absolute_path(path, name)?;
    if !path.starts_with(NIX_STORE_PREFIX) {
        return Err(format!("{name} must be an immutable /nix/store path"));
    }
    Ok(())
}

fn validate_runtime_path(path: &str, name: &str) -> Result<(), String> {
    validate_absolute_path(path, name)?;
    if path.starts_with(NIX_STORE_PREFIX) {
        return Err(format!("{name} must be outside /nix/store"));
    }
    Ok(())
}

fn validate_absolute_path(path: &str, name: &str) -> Result<(), String> {
    validate_canonical_text(path, name)?;
    if !Path::new(path).is_absolute() {
        return Err(format!("{name} must be an absolute path"));
    }
    Ok(())
}

fn validate_canonical_text(value: &str, name: &str) -> Result<(), String> {
    if value.is_empty() || value.trim() != value {
        return Err(format!(
            "{name} must be non-empty without surrounding whitespace"
        ));
    }
    Ok(())
}

fn validate_loopback_address(address: &str) -> Result<(), String> {
    let port = address
        .strip_prefix(LOOPBACK_ADDRESS_PREFIX)
        .ok_or_else(|| "runtime.inspector_address must use 127.0.0.1".to_owned())?;
    let parsed = port
        .parse::<u16>()
        .map_err(|error| format!("runtime.inspector_address has an invalid port: {error}"))?;
    if parsed == 0 {
        return Err("runtime.inspector_address port must be positive".to_owned());
    }
    Ok(())
}

fn validate_loopback_health_url(url: &str) -> Result<(), String> {
    let authority_and_path = url
        .strip_prefix(LOOPBACK_HTTP_PREFIX)
        .ok_or_else(|| "restoration.health_url must use loopback HTTP".to_owned())?;
    let (port, path) = authority_and_path
        .split_once('/')
        .ok_or_else(|| "restoration.health_url must include an absolute path".to_owned())?;
    let parsed = port
        .parse::<u16>()
        .map_err(|error| format!("restoration.health_url has an invalid port: {error}"))?;
    if parsed == 0 || path.is_empty() {
        return Err("restoration.health_url must include a positive port and path".to_owned());
    }
    Ok(())
}

fn validate_sorted_unique_nonempty(values: &[String], name: &str) -> Result<(), String> {
    if values.is_empty() {
        return Err(format!("{name} must not be empty"));
    }
    for value in values {
        validate_canonical_text(value, &format!("{name} entry"))?;
    }
    if values
        .windows(ADJACENT_PAIR_WIDTH)
        .any(|pair| pair[0] >= pair[1])
    {
        return Err(format!("{name} must be strictly sorted and unique"));
    }
    Ok(())
}

fn validate_evidence_shape(evidence: &SessionEvidence) -> Result<(), String> {
    validate_canonical_text(&evidence.plan_id, "evidence.plan_id")?;
    if evidence.plan_id.len() != BLAKE3_HEX_LENGTH
        || !evidence
            .plan_id
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        return Err("evidence.plan_id must be a lowercase BLAKE3 hex digest".to_owned());
    }

    let mut artifact_roles = BTreeSet::new();
    for artifact in &evidence.artifacts {
        validate_canonical_text(&artifact.role, "evidence artifact role")?;
        if !artifact_roles.insert(artifact.role.as_str()) {
            return Err(format!(
                "evidence contains duplicate artifact role: {}",
                artifact.role
            ));
        }
        if artifact.bytes == 0 {
            return Err(format!(
                "evidence artifact {} must be non-empty",
                artifact.role
            ));
        }
        if artifact.blake3.len() != BLAKE3_HEX_LENGTH
            || !artifact
                .blake3
                .bytes()
                .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
        {
            return Err(format!(
                "evidence artifact {} has an invalid BLAKE3 digest",
                artifact.role
            ));
        }
    }

    let mut markers = BTreeSet::new();
    for marker in &evidence.observed_markers {
        validate_canonical_text(marker, "evidence observed marker")?;
        if !markers.insert(marker.as_str()) {
            return Err(format!("evidence contains duplicate marker: {marker}"));
        }
    }
    Ok(())
}

fn safety_issues(manifest: &SessionManifest, evidence: &SessionEvidence) -> Vec<String> {
    let mut issues = Vec::new();
    if evidence.process_attempts > manifest.budget.max_processes {
        issues.push("process attempts exceeded the manifest budget".to_owned());
    }
    if evidence.owner_isolation_attempts > SINGLE_PROCESS_BUDGET {
        issues.push("owner isolation was attempted more than once".to_owned());
    }
    if evidence.restoration_attempts > SINGLE_PROCESS_BUDGET {
        issues.push("owner restoration was attempted more than once".to_owned());
    }
    if evidence.process_attempts == 0 && evidence.process.is_some() {
        issues.push("terminal process evidence exists with zero process attempts".to_owned());
    }
    if evidence.process_attempts == SINGLE_PROCESS_BUDGET && evidence.process.is_none() {
        issues.push("one process attempt lacks a terminal process result".to_owned());
    }
    if evidence.process_attempts == SINGLE_PROCESS_BUDGET
        && evidence.owner_isolation_attempts != SINGLE_PROCESS_BUDGET
    {
        issues.push("the process did not follow exactly one owner isolation".to_owned());
    }
    if evidence.owner_isolation_attempts == SINGLE_PROCESS_BUDGET
        && evidence.restoration_attempts != SINGLE_PROCESS_BUDGET
    {
        issues.push("owner isolation did not retain exactly one restoration attempt".to_owned());
    }
    if evidence.owner_isolation_attempts == 0 && evidence.restoration_attempts != 0 {
        issues.push("owner restoration was attempted without owner isolation".to_owned());
    }
    if evidence.process_attempts == 0
        && evidence
            .observed_markers
            .iter()
            .any(|marker| manifest.evidence.success_markers.contains(marker))
    {
        issues.push("a success marker exists with zero process attempts".to_owned());
    }
    if let Some(process) = &evidence.process
        && process.timed_out
        && process.exit_status != manifest.budget.timeout_exit_status
    {
        issues.push("timed-out process status does not match the manifest".to_owned());
    }

    let recovery_required = evidence.owner_isolation_attempts == SINGLE_PROCESS_BUDGET;
    if recovery_required {
        if evidence.owner_active_after != Some(true) {
            issues.push("owner service was not proven active after isolation".to_owned());
        }
        if evidence.owner_health_status_after != Some(manifest.restoration.expected_health_status) {
            issues.push("owner health status did not match the manifest".to_owned());
        }
        if evidence.board_healthy_after != Some(true) {
            issues.push("board health was not proven after isolation".to_owned());
        }
    }
    issues
}

#[cfg(test)]
mod tests {
    use super::*;

    const DIAGNOSTIC_TIMEOUT_SECONDS: u64 = 600;
    const DIAGNOSTIC_TIMEOUT_STATUS: u16 = 124;
    const KILL_GRACE_SECONDS: u64 = 10;
    const ROLLBACK_DELAY_SECONDS: u64 = 900;
    const EXPECTED_HEALTH_STATUS: u16 = 200;
    const ARTIFACT_BYTES: u64 = 32;
    const INVALID_MULTI_PROCESS_BUDGET: u32 = 2;
    const INVALID_SECOND_ATTEMPT: u32 = 2;
    const INVALID_HEALTH_STATUS: u16 = 503;
    const ARTIFACT_DIGEST: &str =
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const SUCCESS_MARKER: &str = "data-movement device probe: PASS";

    fn valid_manifest() -> SessionManifest {
        SessionManifest {
            schema_version: MANIFEST_SCHEMA_VERSION,
            session_id: "reader-l1-repair-device-1".to_owned(),
            stage: Stage::DataMovement,
            target: Target {
                package_path: "/nix/store/example-ttwkv7".to_owned(),
                kernel_path: "/nix/store/example-ttwkv7-kernels".to_owned(),
                executable: "/nix/store/example-ttwkv7/bin/wkv7-data-movement".to_owned(),
                arguments: vec!["probe".to_owned()],
            },
            hardware: Hardware {
                architecture: "Blackhole P150".to_owned(),
                physical_device: 1,
                device_path: "/dev/tenstorrent/1".to_owned(),
                owner_unit: "owner.service".to_owned(),
                owner_control_path: "/nix/store/example-owner/bin/owner-control".to_owned(),
            },
            runtime: RuntimeState {
                run_root: "/var/tmp/rwkv-lab-session".to_owned(),
                cache_path: "/var/tmp/rwkv-lab-session/cache".to_owned(),
                logs_path: "/var/tmp/rwkv-lab-session/logs".to_owned(),
                inspector_address: "127.0.0.1:43137".to_owned(),
            },
            budget: Budget {
                max_processes: SINGLE_PROCESS_BUDGET,
                timeout_seconds: DIAGNOSTIC_TIMEOUT_SECONDS,
                timeout_exit_status: DIAGNOSTIC_TIMEOUT_STATUS,
                kill_grace_seconds: KILL_GRACE_SECONDS,
            },
            restoration: Restoration {
                rollback_delay_seconds: ROLLBACK_DELAY_SECONDS,
                health_url: "http://127.0.0.1:8000/health".to_owned(),
                expected_health_status: EXPECTED_HEALTH_STATUS,
            },
            evidence: EvidenceExpectations {
                required_artifact_roles: vec![
                    "board_after".to_owned(),
                    "diagnostic_log".to_owned(),
                    "owner_after".to_owned(),
                ],
                success_markers: vec![SUCCESS_MARKER.to_owned()],
            },
            claims: Claims {
                success: "The exact data-movement session completed.".to_owned(),
                non_claims: vec![
                    "No full RWKV correctness is established.".to_owned(),
                    "No token generation is established.".to_owned(),
                ],
            },
        }
    }

    fn artifact(role: &str) -> ArtifactEvidence {
        ArtifactEvidence {
            role: role.to_owned(),
            blake3: ARTIFACT_DIGEST.to_owned(),
            bytes: ARTIFACT_BYTES,
        }
    }

    fn complete_evidence(manifest: &SessionManifest) -> SessionEvidence {
        let identifier = plan_id(manifest).expect("valid manifest must produce a plan identifier");
        SessionEvidence {
            schema_version: EVIDENCE_SCHEMA_VERSION,
            plan_id: identifier,
            process_attempts: SINGLE_PROCESS_BUDGET,
            owner_isolation_attempts: SINGLE_PROCESS_BUDGET,
            restoration_attempts: SINGLE_PROCESS_BUDGET,
            process: Some(ProcessResult {
                exit_status: 0,
                timed_out: false,
            }),
            owner_active_after: Some(true),
            owner_health_status_after: Some(EXPECTED_HEALTH_STATUS),
            board_healthy_after: Some(true),
            artifacts: vec![
                artifact("board_after"),
                artifact("diagnostic_log"),
                artifact("owner_after"),
            ],
            observed_markers: vec![SUCCESS_MARKER.to_owned()],
        }
    }

    #[test]
    fn deterministic_plan_receipt_binds_the_validated_manifest() {
        let manifest = valid_manifest();
        let first = plan_receipt(manifest.clone()).expect("valid manifest must produce a receipt");
        let second = plan_receipt(manifest.clone()).expect("repeated receipt must succeed");
        assert_eq!(first, second);
        assert_eq!(first.schema_version, RECEIPT_SCHEMA_VERSION);
        assert_eq!(first.plan, manifest);
        assert_eq!(first.plan_id.len(), BLAKE3_HEX_LENGTH);
    }

    #[test]
    fn rejects_mutable_paths_reusable_budget_and_insufficient_rollback() {
        let mut mutable_path = valid_manifest();
        mutable_path.target.package_path = "/var/tmp/package".to_owned();
        assert!(
            validate_manifest(&mutable_path)
                .expect_err("mutable package path must fail")
                .contains("immutable /nix/store")
        );

        let mut reusable = valid_manifest();
        reusable.budget.max_processes = INVALID_MULTI_PROCESS_BUDGET;
        assert!(
            validate_manifest(&reusable)
                .expect_err("reusable process budget must fail")
                .contains("max_processes")
        );

        let mut early_rollback = valid_manifest();
        early_rollback.restoration.rollback_delay_seconds = DIAGNOSTIC_TIMEOUT_SECONDS;
        assert!(
            validate_manifest(&early_rollback)
                .expect_err("early rollback must fail")
                .contains("exceed timeout plus kill grace")
        );
    }

    #[test]
    fn rejects_mismatched_device_duplicate_expectations_and_missing_non_claims() {
        let mut device = valid_manifest();
        device.hardware.device_path = "/dev/tenstorrent/0".to_owned();
        assert!(
            validate_manifest(&device)
                .expect_err("mismatched device path must fail")
                .contains("device_path")
        );

        let mut duplicate = valid_manifest();
        duplicate.evidence.required_artifact_roles =
            vec!["diagnostic_log".to_owned(), "diagnostic_log".to_owned()];
        assert!(
            validate_manifest(&duplicate)
                .expect_err("duplicate roles must fail")
                .contains("sorted and unique")
        );

        let mut missing_non_claims = valid_manifest();
        missing_non_claims.claims.non_claims.clear();
        assert!(
            validate_manifest(&missing_non_claims)
                .expect_err("missing non-claims must fail")
                .contains("must not be empty")
        );
    }

    #[test]
    fn classifies_only_complete_zero_status_evidence_as_passed() {
        let manifest = valid_manifest();
        let evidence = complete_evidence(&manifest);
        let receipt = classify(&manifest, &evidence).expect("complete evidence must classify");
        assert_eq!(receipt.outcome, Outcome::Passed);
        assert!(receipt.process_budget_exhausted);
        assert!(receipt.missing_artifact_roles.is_empty());
        assert!(receipt.missing_success_markers.is_empty());
        assert!(receipt.safety_issues.is_empty());
        assert_eq!(receipt.success_claim, Some(manifest.claims.success));
    }

    #[test]
    fn classifies_incomplete_timeout_as_partial_diagnostic() {
        let manifest = valid_manifest();
        let mut evidence = complete_evidence(&manifest);
        evidence.process = Some(ProcessResult {
            exit_status: DIAGNOSTIC_TIMEOUT_STATUS,
            timed_out: true,
        });
        evidence
            .artifacts
            .retain(|item| item.role != "diagnostic_log");
        evidence.observed_markers.clear();
        let receipt = classify(&manifest, &evidence).expect("timeout evidence must classify");
        assert_eq!(receipt.outcome, Outcome::PartialDiagnostic);
        assert!(receipt.process_budget_exhausted);
        assert_eq!(receipt.missing_artifact_roles, vec!["diagnostic_log"]);
        assert_eq!(receipt.missing_success_markers, vec![SUCCESS_MARKER]);
        assert_eq!(receipt.success_claim, None);
    }

    #[test]
    fn classifies_complete_nonzero_or_false_success_as_failed() {
        let manifest = valid_manifest();
        let mut nonzero = complete_evidence(&manifest);
        nonzero.process = Some(ProcessResult {
            exit_status: 1,
            timed_out: false,
        });
        nonzero.observed_markers.clear();
        let nonzero_receipt =
            classify(&manifest, &nonzero).expect("nonzero evidence must classify");
        assert_eq!(nonzero_receipt.outcome, Outcome::Failed);
        assert_eq!(nonzero_receipt.success_claim, None);

        let mut false_success = complete_evidence(&manifest);
        false_success.observed_markers.clear();
        let false_success_receipt =
            classify(&manifest, &false_success).expect("false success must classify");
        assert_eq!(false_success_receipt.outcome, Outcome::Failed);
        assert_eq!(false_success_receipt.success_claim, None);
    }

    #[test]
    fn distinguishes_not_run_from_safely_restored_blocker() {
        let manifest = valid_manifest();
        let identifier = plan_id(&manifest).expect("valid plan must hash");
        let mut evidence = SessionEvidence {
            schema_version: EVIDENCE_SCHEMA_VERSION,
            plan_id: identifier,
            process_attempts: 0,
            owner_isolation_attempts: 0,
            restoration_attempts: 0,
            process: None,
            owner_active_after: None,
            owner_health_status_after: None,
            board_healthy_after: None,
            artifacts: Vec::new(),
            observed_markers: Vec::new(),
        };
        let not_run = classify(&manifest, &evidence).expect("zero-state evidence must classify");
        assert_eq!(not_run.outcome, Outcome::NotRun);
        assert!(!not_run.process_budget_exhausted);

        evidence.owner_isolation_attempts = SINGLE_PROCESS_BUDGET;
        evidence.restoration_attempts = SINGLE_PROCESS_BUDGET;
        evidence.owner_active_after = Some(true);
        evidence.owner_health_status_after = Some(EXPECTED_HEALTH_STATUS);
        evidence.board_healthy_after = Some(true);
        let blocked = classify(&manifest, &evidence).expect("restored blocker must classify");
        assert_eq!(blocked.outcome, Outcome::Blocked);
        assert!(!blocked.process_budget_exhausted);

        evidence.restoration_attempts = 0;
        let unrestored = classify(&manifest, &evidence).expect("unsafe blocker must classify");
        assert_eq!(unrestored.outcome, Outcome::Unsafe);
        assert!(
            unrestored
                .safety_issues
                .iter()
                .any(|issue| issue.contains("restoration attempt"))
        );
    }

    #[test]
    fn safety_violations_outrank_ordinary_results() {
        let manifest = valid_manifest();
        let mut exceeded = complete_evidence(&manifest);
        exceeded.process_attempts = INVALID_SECOND_ATTEMPT;
        let exceeded_receipt =
            classify(&manifest, &exceeded).expect("unsafe evidence must classify");
        assert_eq!(exceeded_receipt.outcome, Outcome::Unsafe);
        assert!(exceeded_receipt.process_budget_exhausted);
        assert!(!exceeded_receipt.safety_issues.is_empty());
        assert_eq!(exceeded_receipt.success_claim, None);

        let mut unhealthy = complete_evidence(&manifest);
        unhealthy.owner_health_status_after = Some(INVALID_HEALTH_STATUS);
        unhealthy.board_healthy_after = Some(false);
        let unhealthy_receipt =
            classify(&manifest, &unhealthy).expect("unhealthy evidence must classify");
        assert_eq!(unhealthy_receipt.outcome, Outcome::Unsafe);
        assert!(
            unhealthy_receipt
                .safety_issues
                .iter()
                .any(|issue| issue.contains("owner health"))
        );
        assert!(
            unhealthy_receipt
                .safety_issues
                .iter()
                .any(|issue| issue.contains("board health"))
        );
    }

    #[test]
    fn rejects_plan_mismatch_timeout_contradiction_and_duplicate_artifacts() {
        let manifest = valid_manifest();
        let mut mismatch = complete_evidence(&manifest);
        mismatch.plan_id = "b".repeat(BLAKE3_HEX_LENGTH);
        assert!(
            classify(&manifest, &mismatch)
                .expect_err("plan mismatch must fail")
                .contains("does not match")
        );

        let mut timeout = complete_evidence(&manifest);
        timeout.process = Some(ProcessResult {
            exit_status: 1,
            timed_out: true,
        });
        let timeout_receipt = classify(&manifest, &timeout).expect("contradiction must classify");
        assert_eq!(timeout_receipt.outcome, Outcome::Unsafe);

        let mut duplicate = complete_evidence(&manifest);
        duplicate.artifacts.push(artifact("diagnostic_log"));
        assert!(
            classify(&manifest, &duplicate)
                .expect_err("duplicate evidence role must fail")
                .contains("duplicate artifact role")
        );
    }
}
