use std::collections::BTreeSet;
use std::env;
use std::process::{Command, ExitCode, Output};

const RAD_PREFIX: &str = "rad:z";
const EMPTY_POLICY_MESSAGE: &str = "No seeding policies to show.";
const POLICY_HEADER: &str = "Repository";
const NO_COLOR: &str = "1";
const SCOPE: &str = "all";

#[derive(Debug, PartialEq, Eq)]
struct Plan {
    remove: Vec<String>,
    add: Vec<String>,
}

fn is_base58_character(character: char) -> bool {
    matches!(
        character,
        '1'..='9'
            | 'A'..='H'
            | 'J'..='N'
            | 'P'..='Z'
            | 'a'..='k'
            | 'm'..='z'
    )
}

fn is_canonical_rid(value: &str) -> bool {
    let Some(payload) = value.strip_prefix(RAD_PREFIX) else {
        return false;
    };
    !payload.is_empty() && payload.chars().all(is_base58_character)
}

fn policy_set(output: &str) -> Result<BTreeSet<String>, String> {
    if output
        .lines()
        .any(|line| line.trim() == EMPTY_POLICY_MESSAGE)
    {
        return Ok(BTreeSet::new());
    }

    let mut header_seen = false;
    let mut policies = BTreeSet::new();

    for line in output.lines() {
        let Some(row) = line.trim_start().strip_prefix('│') else {
            continue;
        };
        let Some(candidate) = row.split_whitespace().next() else {
            continue;
        };
        if candidate == POLICY_HEADER {
            header_seen = true;
            continue;
        }
        if !header_seen {
            return Err("Radicle policy row appeared before the expected header".to_owned());
        }
        if !is_canonical_rid(candidate) {
            return Err(format!(
                "invalid repository ID in Radicle policy output: {candidate}"
            ));
        }
        policies.insert(candidate.to_owned());
    }

    if !header_seen || policies.is_empty() {
        return Err("unrecognized or empty Radicle policy table".to_owned());
    }
    Ok(policies)
}

fn desired_set(arguments: &[String]) -> Result<BTreeSet<String>, String> {
    let mut desired = BTreeSet::new();

    for rid in arguments {
        if !is_canonical_rid(rid) {
            return Err(format!("invalid desired repository ID: {rid}"));
        }
        if !desired.insert(rid.clone()) {
            return Err(format!("duplicate desired repository ID: {rid}"));
        }
    }

    Ok(desired)
}

fn reconcile_plan(current: &BTreeSet<String>, desired: &BTreeSet<String>) -> Plan {
    Plan {
        remove: current.difference(desired).cloned().collect(),
        add: desired.difference(current).cloned().collect(),
    }
}

fn run(rad: &str, arguments: &[&str]) -> Result<Output, String> {
    let output = Command::new(rad)
        .env("NO_COLOR", NO_COLOR)
        .args(arguments)
        .output()
        .map_err(|error| format!("failed to execute {rad}: {error}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!(
            "{rad} {} failed: {}",
            arguments.join(" "),
            stderr.trim()
        ));
    }
    Ok(output)
}

fn list(rad: &str) -> Result<BTreeSet<String>, String> {
    let output = run(rad, &["seed"])?;
    let stderr = String::from_utf8_lossy(&output.stderr);
    if !stderr.trim().is_empty() {
        return Err(format!("rad seed emitted diagnostics: {}", stderr.trim()));
    }
    let stdout = String::from_utf8(output.stdout)
        .map_err(|error| format!("rad seed output was not UTF-8: {error}"))?;
    policy_set(&stdout)
}

fn apply(rad: &str, plan: &Plan) -> Result<(), String> {
    for rid in &plan.remove {
        run(rad, &["unseed", rid])?;
    }
    for rid in &plan.add {
        run(rad, &["seed", "--no-fetch", "--scope", SCOPE, rid])?;
    }
    Ok(())
}

fn reconcile(rad: &str, desired: &BTreeSet<String>) -> Result<Plan, String> {
    let current = list(rad)?;
    let plan = reconcile_plan(&current, desired);
    apply(rad, &plan)?;

    let observed = list(rad)?;
    if observed != *desired {
        return Err(format!(
            "policy reconciliation mismatch: expected {desired:?}, observed {observed:?}"
        ));
    }
    Ok(plan)
}

fn main() -> ExitCode {
    let mut arguments = env::args();
    let Some(_program) = arguments.next() else {
        eprintln!("process argument vector is empty");
        return ExitCode::FAILURE;
    };
    let Some(rad) = arguments.next() else {
        eprintln!("usage: radicle-policy-reconciler <rad-binary> [canonical-rid ...]");
        return ExitCode::FAILURE;
    };
    let desired_arguments = arguments.collect::<Vec<_>>();
    let desired = match desired_set(&desired_arguments) {
        Ok(desired) => desired,
        Err(error) => {
            eprintln!("{error}");
            return ExitCode::FAILURE;
        }
    };

    match reconcile(&rad, &desired) {
        Ok(plan) => {
            println!(
                "reconciled Radicle seeding policy: removed={}, added={}, desired={}",
                plan.remove.len(),
                plan.add.len(),
                desired.len()
            );
            ExitCode::SUCCESS
        }
        Err(error) => {
            eprintln!("{error}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const RID_A: &str = "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5";
    const RID_B: &str = "rad:z4GypKmh1gkEfmkXtarcYnkvtFUfE";

    fn set(values: &[&str]) -> BTreeSet<String> {
        values.iter().map(|value| (*value).to_owned()).collect()
    }

    #[test]
    fn parses_bordered_policy_output() {
        let output = format!(
            "│ Repository Name Policy Scope │\n│ {RID_A} heartwood seed all │\n│ {RID_B} probe seed followed │\n"
        );
        assert_eq!(policy_set(&output), Ok(set(&[RID_A, RID_B])));
    }

    #[test]
    fn accepts_empty_policy_output() {
        assert_eq!(
            policy_set("No seeding policies to show.\n"),
            Ok(BTreeSet::new())
        );
    }

    #[test]
    fn computes_sorted_additions_and_removals() {
        let plan = reconcile_plan(&set(&[RID_A]), &set(&[RID_B]));
        assert_eq!(
            plan,
            Plan {
                remove: vec![RID_A.to_owned()],
                add: vec![RID_B.to_owned()],
            }
        );
    }

    #[test]
    fn rejects_malformed_policy_output() {
        let output = "│ Repository Name Policy Scope │\n│ rad:../host-secret invalid allow all │\n";
        let error = policy_set(output).unwrap_err();
        assert!(error.contains("invalid repository ID"));
    }

    #[test]
    fn ignores_rid_shaped_repository_names() {
        let output = format!("│ Repository Name Policy Scope │\n│ {RID_A} {RID_B} allow all │\n");
        assert_eq!(policy_set(&output), Ok(set(&[RID_A])));
    }

    #[test]
    fn rejects_unrecognized_policy_output() {
        let error = policy_set("policy output changed\n").unwrap_err();
        assert!(error.contains("unrecognized"));
    }

    #[test]
    fn rejects_duplicate_desired_repositories() {
        let arguments = vec![RID_A.to_owned(), RID_A.to_owned()];
        let error = desired_set(&arguments).unwrap_err();
        assert!(error.contains("duplicate desired repository ID"));
    }

    #[test]
    fn rejects_noncanonical_desired_repository() {
        let arguments = vec!["github:OnixResearch/bounded-exec".to_owned()];
        let error = desired_set(&arguments).unwrap_err();
        assert!(error.contains("invalid desired repository ID"));
    }
}
