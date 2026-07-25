//! Imperative filesystem, Radicle, process, artifact, and status shell.

#![forbid(unsafe_code)]

use std::env;
use std::ffi::OsString;
use std::fs::{self, OpenOptions};
use std::io::{self, Write as _};
use std::net::{SocketAddr, TcpStream};
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::time::Duration;

use bounded_exec::{
    CommandSpec, Disposition, EnvironmentMode, ExecutionLimits, Input, OutcomePolicy, RunRequest,
    TerminationScope,
};
use radicle::cob::patch::Patches;
use radicle::cob::store::access::ReadOnly;
use radicle::prelude::*;
use radicle::storage::git::Repository;
use radicle_ci_runner::{
    AdmittedEventV1, CandidateV1, JobResultV1, LockIdentityV1, ObservationV1, RunnerConfigV1,
    RunnerDisposition, TriggerClass, admit_candidate, classify_observation, validate_config,
    validate_event, validate_result,
};
use serde::Serialize;
use serde::de::DeserializeOwned;

// r[impl onix.radicle_ci.execution]

const EXPECTED_ARGUMENT_COUNT: usize = 3;
const SUBCOMMAND_INDEX: usize = 1;
const CONFIG_PATH_INDEX: usize = 2;
const EXIT_FAILURE: u8 = 1;
const LOCK_FILE_COUNT: usize = 4;
const GIT_COMMAND_TIMEOUT_MS: u64 = 120_000;
const GIT_OUTPUT_MAX_BYTES: usize = 16 * 1_048_576;
const GIT_POLL_INTERVAL_MS: u64 = 25;
const GIT_TEARDOWN_TIMEOUT_MS: u64 = 5_000;
const STATUS_TIMEOUT_MS: u64 = 120_000;
const STATUS_OUTPUT_MAX_BYTES: usize = 1_048_576;
const PROBE_NETWORK_TIMEOUT_MS: u64 = 250;
const EMPTY_INPUT_MAX_BYTES: usize = 1;
const FILE_MODE_READ_ONLY: u32 = 0o440;
const SOURCE_FILE_MODE_READ_ONLY: u32 = 0o440;
const SOURCE_DIRECTORY_MODE_READ_ONLY: u32 = 0o550;
const DIRECTORY_MODE_PRIVATE: u32 = 0o700;
const DIRECTORY_MODE_EXCHANGE: u32 = 0o770;

#[derive(Debug)]
struct ShellError(String);

impl std::fmt::Display for ShellError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(&self.0)
    }
}

impl std::error::Error for ShellError {}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("radicle-ci-runner: {error}");
            ExitCode::from(EXIT_FAILURE)
        }
    }
}

fn run() -> Result<(), ShellError> {
    let arguments = env::args().collect::<Vec<_>>();
    if arguments.len() != EXPECTED_ARGUMENT_COUNT {
        return Err(shell_error(
            "usage: radicle-ci-runner <scan|run-next|publish-next|probe-isolation|validate-config> CONFIG.json",
        ));
    }
    let config: RunnerConfigV1 = read_json(Path::new(&arguments[CONFIG_PATH_INDEX]))?;
    validate_config(&config).map_err(|error| shell_error(error.to_string()))?;
    match arguments[SUBCOMMAND_INDEX].as_str() {
        "scan" => scan(&config),
        "run-next" => run_next(&config),
        "publish-next" => publish_next(&config),
        "probe-isolation" => probe_isolation(&config),
        "validate-config" => {
            println!("configuration_result=accepted");
            Ok(())
        }
        _ => Err(shell_error("unknown subcommand")),
    }
}

fn probe_isolation(config: &RunnerConfigV1) -> Result<(), ShellError> {
    let protected_paths = [
        "/run/secrets",
        "/var/lib/radicle",
        config.bot_state_path.as_str(),
        "/root",
        "/home",
        "/etc/ssh",
    ];
    for path in protected_paths {
        match fs::read_dir(path) {
            Err(error) if error.kind() == io::ErrorKind::PermissionDenied => {}
            Err(error) => {
                return Err(shell_error(format!(
                    "isolation probe did not receive permission denial for {path}: {error}"
                )));
            }
            Ok(_) => {
                return Err(shell_error(format!(
                    "isolation probe unexpectedly accessed {path}"
                )));
            }
        }
    }

    let control = Path::new(&config.runner_state_path).join("isolation-positive-control");
    let mut control_file = OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(&control)
        .map_err(|error| shell_io("runner-state positive control was not writable", error))?;
    control_file
        .write_all(b"runner-state-write-allowed\n")
        .map_err(|error| shell_io("failed to write isolation positive control", error))?;
    drop(control_file);
    fs::remove_file(&control)
        .map_err(|error| shell_io("failed to remove isolation positive control", error))?;

    let address = config
        .production_seed_address
        .parse::<SocketAddr>()
        .map_err(|_| shell_error("production seed address is not a socket address"))?;
    if TcpStream::connect_timeout(&address, Duration::from_millis(PROBE_NETWORK_TIMEOUT_MS)).is_ok()
    {
        return Err(shell_error(
            "isolation probe unexpectedly reached the production seed",
        ));
    }

    let receipt = IsolationProbeReceipt {
        schema: "onix.radicle-ci-isolation-probe.v1",
        runner_state_write: "allowed",
        protected_path_access: "denied",
        production_seed_network: "denied",
        canonical_ref_mutation: "unavailable-with-production-storage-denied",
        seed_policy_mutation: "unavailable-with-production-storage-denied",
        cache_write: "unavailable-with-protect-system-strict",
        deployment_and_secret_access: "unavailable-with-run-secrets-denied",
    };
    let json = serde_json::to_string(&receipt)
        .map_err(|_| shell_error("failed to serialize isolation probe receipt"))?;
    println!("{json}");
    Ok(())
}

fn scan(config: &RunnerConfigV1) -> Result<(), ShellError> {
    let paths = ExchangePaths::new(config);
    paths.create_all()?;
    let rid = config
        .rid
        .parse::<RepoId>()
        .map_err(|_| shell_error("configured RID is invalid"))?;
    let repository_path =
        Path::new(&config.storage_path).join(config.rid.trim_start_matches("rad:"));
    let repository = Repository::open(&repository_path, rid)
        .map_err(|error| shell_error(format!("failed to open CI bot repository: {error}")))?;
    verify_delegates(config, &repository)?;

    let (head_ref, head_oid) = repository
        .head()
        .map_err(|error| shell_error(format!("failed to read canonical head: {error}")))?;
    let canonical = CandidateSeed {
        trigger: TriggerClass::CanonicalBranch,
        reference: head_ref.to_string(),
        object_oid: head_oid.to_string(),
        patch_id: None,
        revision_id: None,
    };
    export_candidate(config, &paths, &repository_path, canonical)?;

    let patches = Patches::open(&repository, ReadOnly)
        .map_err(|error| shell_error(format!("failed to open patch store: {error}")))?;
    let proposed = patches
        .proposed()
        .map_err(|error| shell_error(format!("failed to list proposed patches: {error}")))?;
    for (patch_id, patch) in proposed {
        let (revision_id, revision) = patch.latest();
        let seed = CandidateSeed {
            trigger: TriggerClass::Patch,
            reference: format!("refs/cobs/xyz.radicle.patch/{patch_id}"),
            object_oid: revision.head().to_string(),
            patch_id: Some(patch_id.to_string()),
            revision_id: Some(revision_id.to_string()),
        };
        export_candidate(config, &paths, &repository_path, seed)?;
    }
    Ok(())
}

fn run_next(config: &RunnerConfigV1) -> Result<(), ShellError> {
    let paths = ExchangePaths::new(config);
    paths.create_all()?;
    recover_processing(&paths)?;
    let Some(job_name) = first_directory(&paths.incoming)? else {
        println!("runner_result=idle");
        return Ok(());
    };
    let incoming = paths.incoming.join(&job_name);
    let processing = paths.processing.join(&job_name);
    fs::rename(&incoming, &processing)
        .map_err(|error| shell_io("failed to claim incoming job", error))?;

    match execute_claimed_job(config, &paths, &processing) {
        Ok(()) => {
            fs::remove_dir_all(&processing)
                .map_err(|error| shell_io("failed to clean processed job", error))?;
            Ok(())
        }
        Err(error) => {
            let rejected = paths.rejected.join(&job_name);
            if rejected.exists() {
                fs::remove_dir_all(&rejected)
                    .map_err(|source| shell_io("failed to replace rejected job", source))?;
            }
            fs::rename(&processing, &rejected)
                .map_err(|source| shell_io("failed to retain rejected job", source))?;
            Err(error)
        }
    }
}

fn publish_next(config: &RunnerConfigV1) -> Result<(), ShellError> {
    let paths = ExchangePaths::new(config);
    paths.create_all()?;
    let Some(job_name) = first_directory(&paths.outbox)? else {
        println!("publisher_result=idle");
        return Ok(());
    };
    let job_path = paths.outbox.join(&job_name);
    let event: AdmittedEventV1 = read_json(&job_path.join("event.json"))?;
    let result: JobResultV1 = read_json(&job_path.join("result.json"))?;
    validate_event(config, &event).map_err(|error| shell_error(error.to_string()))?;
    validate_result(&event, &result).map_err(|error| shell_error(error.to_string()))?;

    if event.trigger == TriggerClass::Patch {
        let revision_id = event
            .revision_id
            .as_deref()
            .ok_or_else(|| shell_error("patch status lacks revision ID"))?;
        let message = status_message(&result);
        let arguments = [
            "patch",
            "comment",
            revision_id,
            "--message",
            &message,
            "--repo",
            &event.rid,
            "--announce",
            "--quiet",
        ];
        let environment = vec![
            (
                OsString::from("RAD_HOME"),
                OsString::from(&config.bot_state_path),
            ),
            (
                OsString::from("HOME"),
                OsString::from(&config.bot_state_path),
            ),
            (OsString::from("PATH"), executable_path_environment(config)?),
        ];
        let output = run_bounded(
            Path::new(&config.rad_program),
            arguments.iter().map(OsString::from).collect(),
            Path::new("/"),
            environment,
            status_limits(),
        )?;
        if output.disposition != Disposition::Succeeded {
            return Err(shell_error("Radicle patch status publication failed"));
        }
    }

    let published = paths.published.join(&job_name);
    if published.exists() {
        fs::remove_dir_all(&published)
            .map_err(|error| shell_io("failed to replace published result", error))?;
    }
    fs::rename(&job_path, &published)
        .map_err(|error| shell_io("failed to commit published result", error))?;
    println!("publisher_result=published");
    println!("job_id={}", event.job_id);
    Ok(())
}

#[derive(Debug)]
struct CandidateSeed {
    trigger: TriggerClass,
    reference: String,
    object_oid: String,
    patch_id: Option<String>,
    revision_id: Option<String>,
}

fn export_candidate(
    config: &RunnerConfigV1,
    paths: &ExchangePaths,
    repository_path: &Path,
    seed: CandidateSeed,
) -> Result<(), ShellError> {
    if !git_object_exists(config, repository_path, &seed.object_oid)? {
        return Err(shell_error("candidate Git object is missing locally"));
    }
    let observed_locks = observe_locks(config, repository_path, &seed.object_oid)?;
    let temporary_archive = paths.staging.join(format!(
        "source-{}-{}.tar",
        seed.object_oid,
        std::process::id()
    ));
    create_git_archive(
        config,
        repository_path,
        &seed.object_oid,
        &temporary_archive,
    )?;
    let archive_bytes = fs::read(&temporary_archive)
        .map_err(|error| shell_io("failed to read source archive", error))?;
    let source_archive_blake3 = blake3::hash(&archive_bytes).to_hex().to_string();
    let candidate = CandidateV1 {
        rid: config.rid.clone(),
        trigger: seed.trigger,
        reference: seed.reference,
        object_oid: seed.object_oid,
        patch_id: seed.patch_id,
        revision_id: seed.revision_id,
        object_present_locally: true,
        object_is_current: true,
        signed_refs_feature: config.signed_refs_feature.clone(),
        delegate_alignment_verified: true,
        observed_locks,
    };
    let event = admit_candidate(config, &candidate, &source_archive_blake3)
        .map_err(|error| shell_error(error.to_string()))?;
    let ledger = paths.ledger.join(&event.job_id);
    if ledger.exists() {
        fs::remove_file(&temporary_archive).ok();
        println!("scan_result=duplicate");
        println!("job_id={}", event.job_id);
        return Ok(());
    }

    let temporary_job = paths.staging.join(format!("job-{}", event.job_id));
    if temporary_job.exists() {
        fs::remove_dir_all(&temporary_job)
            .map_err(|error| shell_io("failed to clear stale staged job", error))?;
    }
    create_directory(&temporary_job, DIRECTORY_MODE_EXCHANGE)?;
    write_json(&temporary_job.join("event.json"), &event)?;
    fs::rename(&temporary_archive, temporary_job.join("source.tar"))
        .map_err(|error| shell_io("failed to stage source archive", error))?;
    write_file(
        &temporary_job.join("source.blake3"),
        format!("{source_archive_blake3}\n").as_bytes(),
    )?;
    write_file(&temporary_job.join("ready"), b"ready\n")?;
    let incoming = paths.incoming.join(&event.job_id);
    fs::rename(&temporary_job, &incoming)
        .map_err(|error| shell_io("failed to publish incoming job", error))?;
    write_file(&ledger, format!("{}\n", event.object_oid).as_bytes())?;
    println!("scan_result=queued");
    println!("job_id={}", event.job_id);
    println!("object_oid={}", event.object_oid);
    Ok(())
}

fn execute_claimed_job(
    config: &RunnerConfigV1,
    paths: &ExchangePaths,
    processing: &Path,
) -> Result<(), ShellError> {
    let event = load_claimed_event(config, processing)?;
    let (source, home) = materialize_source(config, processing, &event)?;
    let output = execute_nix_job(config, &source, &home)?;
    persist_job_result(config, paths, &event, &output)
}

fn load_claimed_event(
    config: &RunnerConfigV1,
    processing: &Path,
) -> Result<AdmittedEventV1, ShellError> {
    if !processing.join("ready").is_file() {
        return Err(shell_error("claimed job is not complete"));
    }
    let event: AdmittedEventV1 = read_json(&processing.join("event.json"))?;
    validate_event(config, &event).map_err(|error| shell_error(error.to_string()))?;
    let archive = fs::read(processing.join("source.tar"))
        .map_err(|error| shell_io("failed to read claimed source archive", error))?;
    let observed_archive_blake3 = blake3::hash(&archive).to_hex().to_string();
    if observed_archive_blake3 != event.source_archive_blake3 {
        return Err(shell_error("claimed source archive BLAKE3 changed"));
    }
    Ok(event)
}

fn materialize_source(
    config: &RunnerConfigV1,
    processing: &Path,
    event: &AdmittedEventV1,
) -> Result<(PathBuf, PathBuf), ShellError> {
    let work = Path::new(&config.runner_state_path)
        .join("work")
        .join(&event.job_id);
    if work.exists() {
        make_runner_tree_removable(&work)?;
        fs::remove_dir_all(&work)
            .map_err(|error| shell_io("failed to reset job workdir", error))?;
    }
    let source = work.join("source");
    let home = work.join("home");
    create_directory(&source, DIRECTORY_MODE_PRIVATE)?;
    create_directory(&home, DIRECTORY_MODE_PRIVATE)?;
    extract_archive(config, processing, &source)?;
    let observed_locks = observe_worktree_locks(&source)?;
    if observed_locks != config.expected_locks || observed_locks != event.locks {
        return Err(shell_error("materialized source lock identities changed"));
    }
    make_source_read_only(&source)?;
    Ok((source, home))
}

fn execute_nix_job(
    config: &RunnerConfigV1,
    source: &Path,
    home: &Path,
) -> Result<bounded_exec::ExecutionOutput, ShellError> {
    let allowed_input_uris = config.allowed_input_uris.join(" ");
    let nix_config = format!(
        "experimental-features = nix-command flakes\naccept-flake-config = false\nsandbox = false\nsubstituters =\nconnect-timeout = 1\nallowed-uris = {allowed_input_uris}\n"
    );
    let environment = vec![
        (OsString::from("HOME"), home.as_os_str().to_os_string()),
        (
            OsString::from("XDG_CACHE_HOME"),
            Path::new(&config.runner_state_path)
                .join("cache")
                .into_os_string(),
        ),
        (OsString::from("NIX_CONFIG"), OsString::from(nix_config)),
    ];
    let store_uri = format!("local?root={}", config.local_store_root);
    let archive_arguments = vec![
        OsString::from("--offline"),
        OsString::from("--option"),
        OsString::from("substituters"),
        OsString::from(""),
        OsString::from("flake"),
        OsString::from("archive"),
        OsString::from("--to"),
        OsString::from(&store_uri),
        OsString::from("--no-update-lock-file"),
        OsString::from("."),
    ];
    let preparation = run_bounded(
        Path::new(&config.nix_program),
        archive_arguments,
        source,
        environment.clone(),
        execution_limits(config),
    )?;
    if preparation.disposition != Disposition::Succeeded {
        return Ok(preparation);
    }
    let mut build_arguments = vec![
        OsString::from("--store"),
        OsString::from(&store_uri),
        OsString::from("--offline"),
        OsString::from("--option"),
        OsString::from("substituters"),
        OsString::from(""),
    ];
    build_arguments.extend(config.command_arguments.iter().map(OsString::from));
    run_bounded(
        Path::new(&config.command_program),
        build_arguments,
        source,
        environment,
        execution_limits(config),
    )
}

fn persist_job_result(
    config: &RunnerConfigV1,
    paths: &ExchangePaths,
    event: &AdmittedEventV1,
    output: &bounded_exec::ExecutionOutput,
) -> Result<(), ShellError> {
    let artifact_directory = Path::new(&config.artifact_path).join(&event.job_id);
    if artifact_directory.exists() {
        fs::remove_dir_all(&artifact_directory)
            .map_err(|error| shell_io("failed to replace job artifact", error))?;
    }
    create_directory(&artifact_directory, DIRECTORY_MODE_EXCHANGE)?;
    write_file(&artifact_directory.join("stdout.log"), &output.stdout.bytes)?;
    write_file(&artifact_directory.join("stderr.log"), &output.stderr.bytes)?;
    let stdout_blake3 = blake3::hash(&output.stdout.bytes).to_hex().to_string();
    let stderr_blake3 = blake3::hash(&output.stderr.bytes).to_hex().to_string();
    let manifest = ArtifactManifest {
        schema: "onix.radicle-ci-artifact.v1",
        job_id: &event.job_id,
        object_oid: &event.object_oid,
        stdout_blake3: &stdout_blake3,
        stderr_blake3: &stderr_blake3,
    };
    let manifest_bytes = serde_json::to_vec_pretty(&manifest)
        .map_err(|_| shell_error("failed to serialize artifact manifest"))?;
    write_file(&artifact_directory.join("manifest.json"), &manifest_bytes)?;
    let observation = observation_from_output(output, &manifest_bytes)?;
    let result = classify_observation(config, event, &observation)
        .map_err(|error| shell_error(error.to_string()))?;
    publish_result_to_outbox(paths, event, &result, &artifact_directory)?;
    println!("runner_result=completed");
    println!("job_id={}", event.job_id);
    println!("disposition={:?}", result.disposition);
    Ok(())
}

fn observation_from_output(
    output: &bounded_exec::ExecutionOutput,
    manifest_bytes: &[u8],
) -> Result<ObservationV1, ShellError> {
    Ok(ObservationV1 {
        disposition: map_disposition(output.disposition),
        exit_code: output.exit_code,
        stdout_observed_bytes: u64::try_from(output.stdout.observed_bytes)
            .map_err(|_| shell_error("stdout byte count overflow"))?,
        stdout_retained_bytes: u64::try_from(output.stdout.bytes.len())
            .map_err(|_| shell_error("stdout retained byte count overflow"))?,
        stdout_blake3: blake3::hash(&output.stdout.bytes).to_hex().to_string(),
        stderr_observed_bytes: u64::try_from(output.stderr.observed_bytes)
            .map_err(|_| shell_error("stderr byte count overflow"))?,
        stderr_retained_bytes: u64::try_from(output.stderr.bytes.len())
            .map_err(|_| shell_error("stderr retained byte count overflow"))?,
        stderr_blake3: blake3::hash(&output.stderr.bytes).to_hex().to_string(),
        artifact_bytes: directory_artifact_bytes(
            &output.stdout.bytes,
            &output.stderr.bytes,
            manifest_bytes,
        )?,
        artifact_blake3: blake3::hash(manifest_bytes).to_hex().to_string(),
    })
}

fn publish_result_to_outbox(
    paths: &ExchangePaths,
    event: &AdmittedEventV1,
    result: &JobResultV1,
    artifact_directory: &Path,
) -> Result<(), ShellError> {
    let temporary = paths.staging.join(format!("result-{}", event.job_id));
    if temporary.exists() {
        fs::remove_dir_all(&temporary)
            .map_err(|error| shell_io("failed to clear staged result", error))?;
    }
    create_directory(&temporary, DIRECTORY_MODE_EXCHANGE)?;
    write_json(&temporary.join("event.json"), event)?;
    write_json(&temporary.join("result.json"), result)?;
    write_file(
        &temporary.join("artifact.path"),
        format!("{}\n", artifact_directory.display()).as_bytes(),
    )?;
    let outbox = paths.outbox.join(&event.job_id);
    if outbox.exists() {
        fs::remove_dir_all(&outbox)
            .map_err(|error| shell_io("failed to replace pending result", error))?;
    }
    fs::rename(&temporary, &outbox).map_err(|error| shell_io("failed to publish job result", error))
}

#[derive(Serialize)]
struct IsolationProbeReceipt<'a> {
    schema: &'a str,
    runner_state_write: &'a str,
    protected_path_access: &'a str,
    production_seed_network: &'a str,
    canonical_ref_mutation: &'a str,
    seed_policy_mutation: &'a str,
    cache_write: &'a str,
    deployment_and_secret_access: &'a str,
}

#[derive(Serialize)]
struct ArtifactManifest<'a> {
    schema: &'static str,
    job_id: &'a str,
    object_oid: &'a str,
    stdout_blake3: &'a str,
    stderr_blake3: &'a str,
}

struct ExchangePaths {
    root: PathBuf,
    incoming: PathBuf,
    processing: PathBuf,
    outbox: PathBuf,
    published: PathBuf,
    rejected: PathBuf,
    ledger: PathBuf,
    staging: PathBuf,
}

impl ExchangePaths {
    fn new(config: &RunnerConfigV1) -> Self {
        let root = PathBuf::from(&config.exchange_path);
        Self {
            incoming: root.join("incoming"),
            processing: root.join("processing"),
            outbox: root.join("outbox"),
            published: root.join("published"),
            rejected: root.join("rejected"),
            ledger: root.join("ledger"),
            staging: root.join("staging"),
            root,
        }
    }

    fn create_all(&self) -> Result<(), ShellError> {
        create_directory(&self.root, DIRECTORY_MODE_EXCHANGE)?;
        for path in [
            &self.incoming,
            &self.processing,
            &self.outbox,
            &self.published,
            &self.rejected,
            &self.ledger,
            &self.staging,
        ] {
            create_directory(path, DIRECTORY_MODE_EXCHANGE)?;
        }
        Ok(())
    }
}

fn verify_delegates(config: &RunnerConfigV1, repository: &Repository) -> Result<(), ShellError> {
    let mut actual = repository
        .delegates()
        .map_err(|error| shell_error(format!("failed to read repository delegates: {error}")))?
        .into_iter()
        .map(|delegate| delegate.to_string())
        .collect::<Vec<_>>();
    let mut expected = config.delegates.clone();
    actual.sort();
    expected.sort();
    if actual != expected {
        return Err(shell_error(
            "repository delegate set does not match CI policy",
        ));
    }
    Ok(())
}

fn observe_locks(
    config: &RunnerConfigV1,
    repository: &Path,
    object_oid: &str,
) -> Result<LockIdentityV1, ShellError> {
    let mut digests = Vec::with_capacity(LOCK_FILE_COUNT);
    for file in ["Cargo.toml", "Cargo.lock", "flake.nix", "flake.lock"] {
        let object = format!("{object_oid}:{file}");
        let output = run_bounded(
            Path::new(&config.git_program),
            vec![
                OsString::from("--git-dir"),
                repository.as_os_str().to_os_string(),
                OsString::from("show"),
                OsString::from(object),
            ],
            Path::new("/"),
            Vec::new(),
            git_limits(),
        )?;
        if output.disposition != Disposition::Succeeded || output.stdout.truncated {
            return Err(shell_error(
                "failed to read bounded control file from Git object",
            ));
        }
        digests.push(blake3::hash(&output.stdout.bytes).to_hex().to_string());
    }
    lock_identity_from_digests(&digests)
}

fn observe_worktree_locks(source: &Path) -> Result<LockIdentityV1, ShellError> {
    let mut digests = Vec::with_capacity(LOCK_FILE_COUNT);
    for file in ["Cargo.toml", "Cargo.lock", "flake.nix", "flake.lock"] {
        let bytes = fs::read(source.join(file))
            .map_err(|error| shell_io("failed to read materialized control file", error))?;
        if bytes.len() > GIT_OUTPUT_MAX_BYTES {
            return Err(shell_error("materialized control file exceeds hard bound"));
        }
        digests.push(blake3::hash(&bytes).to_hex().to_string());
    }
    lock_identity_from_digests(&digests)
}

fn lock_identity_from_digests(digests: &[String]) -> Result<LockIdentityV1, ShellError> {
    if digests.len() != LOCK_FILE_COUNT {
        return Err(shell_error("control-file digest count is invalid"));
    }
    Ok(LockIdentityV1 {
        cargo_toml_blake3: digests[0].clone(),
        cargo_lock_blake3: digests[1].clone(),
        flake_nix_blake3: digests[2].clone(),
        flake_lock_blake3: digests[3].clone(),
    })
}

fn git_object_exists(
    config: &RunnerConfigV1,
    repository: &Path,
    object_oid: &str,
) -> Result<bool, ShellError> {
    let commit = format!("{object_oid}^{{commit}}");
    let output = run_bounded(
        Path::new(&config.git_program),
        vec![
            OsString::from("--git-dir"),
            repository.as_os_str().to_os_string(),
            OsString::from("cat-file"),
            OsString::from("-e"),
            OsString::from(commit),
        ],
        Path::new("/"),
        Vec::new(),
        git_limits(),
    )?;
    Ok(output.disposition == Disposition::Succeeded)
}

fn create_git_archive(
    config: &RunnerConfigV1,
    repository: &Path,
    object_oid: &str,
    output_path: &Path,
) -> Result<(), ShellError> {
    let output = run_bounded(
        Path::new(&config.git_program),
        vec![
            OsString::from("--git-dir"),
            repository.as_os_str().to_os_string(),
            OsString::from("archive"),
            OsString::from("--format=tar"),
            OsString::from("--output"),
            output_path.as_os_str().to_os_string(),
            OsString::from(object_oid),
        ],
        Path::new("/"),
        Vec::new(),
        git_limits(),
    )?;
    if output.disposition != Disposition::Succeeded {
        return Err(shell_error("Git source archive failed"));
    }
    let metadata = fs::metadata(output_path)
        .map_err(|error| shell_io("Git source archive is missing", error))?;
    if metadata.len() == 0 || metadata.len() > config.limits.artifact_max_bytes {
        return Err(shell_error(
            "Git source archive is empty or above artifact bound",
        ));
    }
    set_mode(output_path, FILE_MODE_READ_ONLY)?;
    Ok(())
}

fn extract_archive(
    config: &RunnerConfigV1,
    processing: &Path,
    destination: &Path,
) -> Result<(), ShellError> {
    let output = run_bounded(
        Path::new(&config.tar_program),
        vec![
            OsString::from("--extract"),
            OsString::from("--file"),
            processing.join("source.tar").into_os_string(),
            OsString::from("--directory"),
            destination.as_os_str().to_os_string(),
            OsString::from("--no-same-owner"),
            OsString::from("--no-same-permissions"),
        ],
        Path::new("/"),
        Vec::new(),
        git_limits(),
    )?;
    if output.disposition != Disposition::Succeeded {
        return Err(shell_error("source archive extraction failed"));
    }
    Ok(())
}

fn make_runner_tree_removable(path: &Path) -> Result<(), ShellError> {
    let metadata = fs::symlink_metadata(path)
        .map_err(|error| shell_io("failed to inspect prior runner work", error))?;
    if metadata.file_type().is_symlink() || metadata.is_file() {
        return Ok(());
    }
    if !metadata.is_dir() {
        return Err(shell_error(
            "prior runner work contains an unsupported filesystem object",
        ));
    }
    set_mode(path, DIRECTORY_MODE_PRIVATE)?;
    let entries = fs::read_dir(path)
        .map_err(|error| shell_io("failed to traverse prior runner work", error))?;
    for entry in entries {
        let entry = entry.map_err(|error| shell_io("failed to read prior runner work", error))?;
        make_runner_tree_removable(&entry.path())?;
    }
    Ok(())
}

fn make_source_read_only(path: &Path) -> Result<(), ShellError> {
    let metadata = fs::symlink_metadata(path)
        .map_err(|error| shell_io("failed to inspect materialized source", error))?;
    if metadata.file_type().is_symlink() {
        return Ok(());
    }
    if metadata.is_dir() {
        let entries = fs::read_dir(path)
            .map_err(|error| shell_io("failed to traverse materialized source", error))?;
        for entry in entries {
            let entry = entry
                .map_err(|error| shell_io("failed to read materialized source entry", error))?;
            make_source_read_only(&entry.path())?;
        }
        set_mode(path, SOURCE_DIRECTORY_MODE_READ_ONLY)
    } else if metadata.is_file() {
        set_mode(path, SOURCE_FILE_MODE_READ_ONLY)
    } else {
        Err(shell_error(
            "materialized source contains an unsupported filesystem object",
        ))
    }
}

fn run_bounded(
    program: &Path,
    arguments: Vec<OsString>,
    current_dir: &Path,
    environment: Vec<(OsString, OsString)>,
    limits: ExecutionLimits,
) -> Result<bounded_exec::ExecutionOutput, ShellError> {
    let policy = OutcomePolicy::new(vec![0], true, true)
        .map_err(|error| shell_error(format!("invalid outcome policy: {error:?}")))?;
    bounded_exec::run(RunRequest {
        command: CommandSpec {
            program: program.to_path_buf(),
            args: arguments,
            current_dir: current_dir.to_path_buf(),
            environment_mode: EnvironmentMode::Clear,
            environment,
            input: Input::Null,
        },
        limits,
        termination_scope: TerminationScope::ProcessGroup,
        outcome_policy: policy,
    })
    .map_err(|error| shell_error(format!("bounded process failed: {error}")))
}

fn execution_limits(config: &RunnerConfigV1) -> ExecutionLimits {
    ExecutionLimits {
        timeout_ms: config.limits.timeout_ms,
        stdin_max_bytes: config.limits.stdin_max_bytes,
        stdout_max_bytes: config.limits.stdout_max_bytes,
        stderr_max_bytes: config.limits.stderr_max_bytes,
        poll_interval_ms: config.limits.poll_interval_ms,
        teardown_timeout_ms: config.limits.teardown_timeout_ms,
    }
}

const fn git_limits() -> ExecutionLimits {
    ExecutionLimits {
        timeout_ms: GIT_COMMAND_TIMEOUT_MS,
        stdin_max_bytes: EMPTY_INPUT_MAX_BYTES,
        stdout_max_bytes: GIT_OUTPUT_MAX_BYTES,
        stderr_max_bytes: GIT_OUTPUT_MAX_BYTES,
        poll_interval_ms: GIT_POLL_INTERVAL_MS,
        teardown_timeout_ms: GIT_TEARDOWN_TIMEOUT_MS,
    }
}

const fn status_limits() -> ExecutionLimits {
    ExecutionLimits {
        timeout_ms: STATUS_TIMEOUT_MS,
        stdin_max_bytes: EMPTY_INPUT_MAX_BYTES,
        stdout_max_bytes: STATUS_OUTPUT_MAX_BYTES,
        stderr_max_bytes: STATUS_OUTPUT_MAX_BYTES,
        poll_interval_ms: GIT_POLL_INTERVAL_MS,
        teardown_timeout_ms: GIT_TEARDOWN_TIMEOUT_MS,
    }
}

const fn map_disposition(disposition: Disposition) -> RunnerDisposition {
    match disposition {
        Disposition::Succeeded => RunnerDisposition::Succeeded,
        Disposition::ExitFailed => RunnerDisposition::ExitFailed,
        Disposition::TimedOut => RunnerDisposition::TimedOut,
        Disposition::Cancelled => RunnerDisposition::Cancelled,
        Disposition::OutputLimitExceeded(_) => RunnerDisposition::OutputLimitExceeded,
    }
}

fn executable_path_environment(config: &RunnerConfigV1) -> Result<OsString, ShellError> {
    let mut directories = Vec::new();
    for executable in [
        &config.git_program,
        &config.rad_program,
        &config.ssh_program,
    ] {
        let directory = Path::new(executable)
            .parent()
            .ok_or_else(|| shell_error("configured executable has no parent directory"))?;
        directories.push(directory.as_os_str());
    }
    env::join_paths(directories)
        .map_err(|_| shell_error("configured executable search path is invalid"))
}

fn status_message(result: &JobResultV1) -> String {
    format!(
        "Onix CI `{}` for `{}`: **{:?}**. Artifact BLAKE3 `{}`. Scope: bounded observation only; this is not merge or release approval.",
        result.job_id, result.object_oid, result.disposition, result.artifact_blake3
    )
}

fn directory_artifact_bytes(
    stdout: &[u8],
    stderr: &[u8],
    manifest: &[u8],
) -> Result<u64, ShellError> {
    let total = stdout
        .len()
        .checked_add(stderr.len())
        .and_then(|value| value.checked_add(manifest.len()))
        .ok_or_else(|| shell_error("artifact byte count overflow"))?;
    u64::try_from(total).map_err(|_| shell_error("artifact byte count is not representable"))
}

fn recover_processing(paths: &ExchangePaths) -> Result<(), ShellError> {
    for name in directory_names(&paths.processing)? {
        let from = paths.processing.join(&name);
        let to = paths.incoming.join(&name);
        if to.exists() {
            fs::remove_dir_all(&from)
                .map_err(|error| shell_io("failed to remove duplicate processing job", error))?;
        } else {
            fs::rename(&from, &to)
                .map_err(|error| shell_io("failed to recover interrupted job", error))?;
        }
    }
    Ok(())
}

fn first_directory(path: &Path) -> Result<Option<String>, ShellError> {
    Ok(directory_names(path)?.into_iter().next())
}

fn directory_names(path: &Path) -> Result<Vec<String>, ShellError> {
    let mut names = Vec::new();
    let entries = fs::read_dir(path).map_err(|error| shell_io("failed to read queue", error))?;
    for entry in entries {
        let entry = entry.map_err(|error| shell_io("failed to read queue entry", error))?;
        let file_type = entry
            .file_type()
            .map_err(|error| shell_io("failed to inspect queue entry", error))?;
        if !file_type.is_dir() {
            continue;
        }
        let name = entry
            .file_name()
            .into_string()
            .map_err(|_| shell_error("queue entry name is not UTF-8"))?;
        names.push(name);
    }
    names.sort();
    Ok(names)
}

fn create_directory(path: &Path, mode: u32) -> Result<(), ShellError> {
    if path.exists() {
        return path
            .is_dir()
            .then_some(())
            .ok_or_else(|| shell_error("directory path is occupied by a non-directory"));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::DirBuilderExt as _;

        let mut builder = fs::DirBuilder::new();
        builder.recursive(true).mode(mode);
        builder
            .create(path)
            .map_err(|error| shell_io("failed to create directory", error))?;
    }
    #[cfg(not(unix))]
    {
        fs::create_dir_all(path).map_err(|error| shell_io("failed to create directory", error))?;
    }
    Ok(())
}

fn set_mode(path: &Path, mode: u32) -> Result<(), ShellError> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt as _;
        fs::set_permissions(path, fs::Permissions::from_mode(mode))
            .map_err(|error| shell_io("failed to set filesystem mode", error))?;
    }
    Ok(())
}

fn write_json(path: &Path, value: &impl Serialize) -> Result<(), ShellError> {
    let mut bytes =
        serde_json::to_vec_pretty(value).map_err(|_| shell_error("failed to serialize JSON"))?;
    bytes.push(b'\n');
    write_file(path, &bytes)
}

fn read_json<T: DeserializeOwned>(path: &Path) -> Result<T, ShellError> {
    let bytes = fs::read(path).map_err(|error| shell_io("failed to read JSON", error))?;
    serde_json::from_slice(&bytes).map_err(|error| shell_error(format!("invalid JSON: {error}")))
}

fn write_file(path: &Path, bytes: &[u8]) -> Result<(), ShellError> {
    let parent = path
        .parent()
        .ok_or_else(|| shell_error("output path has no parent"))?;
    create_directory(parent, DIRECTORY_MODE_EXCHANGE)?;
    let temporary = parent.join(format!(
        ".tmp-{}-{}",
        std::process::id(),
        path.file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("file")
    ));
    let mut output = OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(&temporary)
        .map_err(|error| shell_io("failed to create temporary output", error))?;
    output
        .write_all(bytes)
        .map_err(|error| shell_io("failed to write temporary output", error))?;
    output
        .sync_all()
        .map_err(|error| shell_io("failed to sync temporary output", error))?;
    set_mode(&temporary, FILE_MODE_READ_ONLY)?;
    fs::rename(&temporary, path).map_err(|error| shell_io("failed to commit output", error))
}

fn shell_io(context: &str, error: io::Error) -> ShellError {
    let message = format!("{context}: {error}");
    drop(error);
    shell_error(message)
}

fn shell_error(message: impl Into<String>) -> ShellError {
    ShellError(message.into())
}

#[cfg(test)]
mod tests {
    use super::*;

    const EXISTING_MODE: u32 = 0o700;
    const REQUESTED_MODE: u32 = 0o770;

    #[test]
    fn existing_shared_directory_keeps_its_owner_selected_mode() {
        use std::os::unix::fs::PermissionsExt as _;

        let path = test_path("existing-directory");
        fs::create_dir_all(&path).expect("create fixture directory");
        set_mode(&path, EXISTING_MODE).expect("set fixture mode");
        create_directory(&path, REQUESTED_MODE).expect("reuse existing directory");
        let mode = fs::metadata(&path)
            .expect("read fixture mode")
            .permissions()
            .mode()
            & REQUESTED_MODE;
        assert_eq!(mode, EXISTING_MODE);
        fs::remove_dir_all(path).expect("remove fixture directory");
    }

    #[test]
    fn prior_read_only_work_can_be_reopened_for_owned_cleanup() {
        let path = test_path("read-only-retry");
        let nested = path.join("nested");
        fs::create_dir_all(&nested).expect("create read-only fixture");
        fs::write(nested.join("source"), b"fixture").expect("write source fixture");
        make_source_read_only(&path).expect("make fixture read-only");
        make_runner_tree_removable(&path).expect("reopen owned fixture");
        fs::remove_dir_all(path).expect("remove reopened fixture");
    }

    #[test]
    fn directory_creation_rejects_an_existing_file() {
        let path = test_path("existing-file");
        fs::write(&path, b"not-a-directory").expect("create fixture file");
        assert!(create_directory(&path, REQUESTED_MODE).is_err());
        fs::remove_file(path).expect("remove fixture file");
    }

    fn test_path(label: &str) -> PathBuf {
        env::temp_dir().join(format!("radicle-ci-runner-{label}-{}", std::process::id()))
    }
}
