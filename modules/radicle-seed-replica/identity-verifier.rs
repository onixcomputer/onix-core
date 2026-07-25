// r[impl onix.radicle_replica.deployment]
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

const CREDENTIALS_DIRECTORY_ENV: &str = "CREDENTIALS_DIRECTORY";
const PRIVATE_KEY_CREDENTIAL: &str = "dev.radicle.node.secret";
const SSH_KEYGEN_PROGRAM: &str = "ssh-keygen";
const EXPECTED_ARGUMENT_COUNT: usize = 3;
const EXPECTED_FINGERPRINT_ARGUMENT_INDEX: usize = 1;
const PUBLIC_KEY_PATH_ARGUMENT_INDEX: usize = 2;
const KEY_TYPE_FIELD_INDEX: usize = 0;
const KEY_DATA_FIELD_INDEX: usize = 1;
const FINGERPRINT_FIELD_INDEX: usize = 1;

fn normalize_public_key(input: &str) -> Result<String, &'static str> {
    let fields = input.split_whitespace().collect::<Vec<_>>();
    if fields.len() <= KEY_DATA_FIELD_INDEX {
        return Err("public key must contain key type and key data");
    }
    if fields[KEY_TYPE_FIELD_INDEX] != "ssh-ed25519" {
        return Err("public key type must be ssh-ed25519");
    }
    Ok(format!(
        "{} {}",
        fields[KEY_TYPE_FIELD_INDEX], fields[KEY_DATA_FIELD_INDEX]
    ))
}

fn parse_fingerprint(output: &str) -> Result<&str, &'static str> {
    output
        .split_whitespace()
        .nth(FINGERPRINT_FIELD_INDEX)
        .ok_or("ssh-keygen fingerprint output is incomplete")
}

fn verify_observations(
    expected_fingerprint: &str,
    declared_public_key: &str,
    derived_public_key: &str,
    fingerprint_output: &str,
) -> Result<(), &'static str> {
    let declared = normalize_public_key(declared_public_key)?;
    let derived = normalize_public_key(derived_public_key)?;
    if declared != derived {
        return Err("Radicle private and public key halves do not match");
    }
    let observed_fingerprint = parse_fingerprint(fingerprint_output)?;
    if observed_fingerprint != expected_fingerprint {
        return Err("Radicle node fingerprint does not match typed policy");
    }
    Ok(())
}

fn credential_path() -> Result<PathBuf, &'static str> {
    let directory = env::var_os(CREDENTIALS_DIRECTORY_ENV)
        .ok_or("systemd credential directory is unavailable")?;
    Ok(PathBuf::from(directory).join(PRIVATE_KEY_CREDENTIAL))
}

fn command_stdout(program: &str, arguments: &[&str]) -> Result<String, &'static str> {
    let output = Command::new(program)
        .args(arguments)
        .output()
        .map_err(|_| "failed to execute ssh-keygen")?;
    if !output.status.success() {
        return Err("ssh-keygen rejected the Radicle identity input");
    }
    String::from_utf8(output.stdout).map_err(|_| "ssh-keygen output is not UTF-8")
}

fn verify_identity(expected_fingerprint: &str, public_key_path: &Path) -> Result<(), &'static str> {
    let private_key_path = credential_path()?;
    let declared_public_key = fs::read_to_string(public_key_path)
        .map_err(|_| "failed to read declared Radicle public key")?;
    let private_path = private_key_path
        .to_str()
        .ok_or("Radicle private key credential path is not UTF-8")?;
    let public_path = public_key_path
        .to_str()
        .ok_or("Radicle public key path is not UTF-8")?;
    let derived_public_key = command_stdout(SSH_KEYGEN_PROGRAM, &["-y", "-f", private_path])?;
    let fingerprint_output =
        command_stdout(SSH_KEYGEN_PROGRAM, &["-E", "sha256", "-lf", public_path])?;
    verify_observations(
        expected_fingerprint,
        &declared_public_key,
        &derived_public_key,
        &fingerprint_output,
    )
}

fn run() -> Result<(), &'static str> {
    let arguments = env::args().collect::<Vec<_>>();
    if arguments.len() != EXPECTED_ARGUMENT_COUNT {
        return Err("usage: radicle-replica-identity-verify EXPECTED_FINGERPRINT PUBLIC_KEY_PATH");
    }
    let expected_fingerprint = &arguments[EXPECTED_FINGERPRINT_ARGUMENT_INDEX];
    let public_key_path = Path::new(&arguments[PUBLIC_KEY_PATH_ARGUMENT_INDEX]);
    verify_identity(expected_fingerprint, public_key_path)?;
    println!("identity_result=verified");
    println!("node_fingerprint={expected_fingerprint}");
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("radicle-replica-identity-verify: {message}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{normalize_public_key, parse_fingerprint, verify_observations};

    const KEY_DATA_A: &str = "AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    const KEY_DATA_B: &str = "AAAAC3NzaC1lZDI1NTE5AAAAIBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB";
    const FINGERPRINT: &str = "SHA256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const ED25519_KEY_BITS: &str = "256";

    #[test]
    fn accepts_matching_ed25519_pair_and_fingerprint() {
        let declared = format!("ssh-ed25519 {KEY_DATA_A} replica");
        let derived = format!("ssh-ed25519 {KEY_DATA_A}");
        let fingerprint = format!("{ED25519_KEY_BITS} {FINGERPRINT} replica (ED25519)");
        assert_eq!(
            verify_observations(FINGERPRINT, &declared, &derived, &fingerprint),
            Ok(())
        );
    }

    #[test]
    fn rejects_mismatched_key_halves() {
        let declared = format!("ssh-ed25519 {KEY_DATA_A}");
        let derived = format!("ssh-ed25519 {KEY_DATA_B}");
        let fingerprint = format!("{ED25519_KEY_BITS} {FINGERPRINT} replica (ED25519)");
        assert_eq!(
            verify_observations(FINGERPRINT, &declared, &derived, &fingerprint),
            Err("Radicle private and public key halves do not match")
        );
    }

    #[test]
    fn rejects_changed_fingerprint() {
        let key = format!("ssh-ed25519 {KEY_DATA_A}");
        let fingerprint = format!("{ED25519_KEY_BITS} SHA256:changed replica (ED25519)");
        assert_eq!(
            verify_observations(FINGERPRINT, &key, &key, &fingerprint),
            Err("Radicle node fingerprint does not match typed policy")
        );
    }

    #[test]
    fn rejects_malformed_or_wrong_type_public_keys() {
        assert!(normalize_public_key("missing").is_err());
        assert!(normalize_public_key(&format!("ssh-rsa {KEY_DATA_A}")).is_err());
    }

    #[test]
    fn rejects_incomplete_fingerprint_output() {
        assert!(parse_fingerprint("missing").is_err());
    }
}
