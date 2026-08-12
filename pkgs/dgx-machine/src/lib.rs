//! Pure command policy for the device-free DGX machine shell.

use std::fmt;

const MACHINE_NAME_FIRST_MESSAGE: &str =
    "a machine name must start with an ASCII letter or underscore";
const MACHINE_NAME_REST_MESSAGE: &str =
    "a machine name can contain only ASCII letters, digits, underscores, and hyphens";
const DESTRUCTIVE_MESSAGE: &str = "install and deploy require a separate authorized Cairn change";
const INFO_ARGUMENT_COUNT: usize = 1;
const BUILD_ARGUMENT_COUNT: usize = 2;

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Operation {
    Info,
    Build { name: String },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Invocation {
    pub args: Vec<String>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum PolicyError {
    MissingCommand,
    UnexpectedArguments { command: String },
    DestructiveCommand { command: String },
    UnsupportedCommand { command: String },
    InvalidMachineName { name: String, reason: &'static str },
    UndeclaredMachine { name: String },
    ChildFailed { code: Option<i32> },
}

impl fmt::Display for PolicyError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingCommand => formatter.write_str("usage: dgx-machine info | build <name>"),
            Self::UnexpectedArguments { command } => {
                write!(formatter, "{command}: unexpected arguments")
            }
            Self::DestructiveCommand { command } => {
                write!(formatter, "{command}: {DESTRUCTIVE_MESSAGE}")
            }
            Self::UnsupportedCommand { command } => {
                write!(formatter, "unsupported DGX command: {command}")
            }
            Self::InvalidMachineName { name, reason } => {
                write!(formatter, "invalid machine name {name:?}: {reason}")
            }
            Self::UndeclaredMachine { name } => {
                write!(formatter, "undeclared DGX machine: {name}")
            }
            Self::ChildFailed { code: Some(code) } => {
                write!(
                    formatter,
                    "pinned Devenv command failed with exit code {code}"
                )
            }
            Self::ChildFailed { code: None } => {
                formatter.write_str("pinned Devenv command ended without an exit code")
            }
        }
    }
}

impl std::error::Error for PolicyError {}

#[must_use]
pub fn declared_names(encoded_names: &str) -> Vec<String> {
    let mut names: Vec<String> = encoded_names
        .lines()
        .filter(|name| !name.is_empty())
        .map(str::to_owned)
        .collect();
    names.sort();
    names.dedup();
    names
}

pub fn parse_operation(args: &[String], declared: &[String]) -> Result<Operation, PolicyError> {
    let Some(command) = args.first() else {
        return Err(PolicyError::MissingCommand);
    };

    match command.as_str() {
        "info" => {
            if args.len() != INFO_ARGUMENT_COUNT {
                return Err(PolicyError::UnexpectedArguments {
                    command: command.clone(),
                });
            }
            Ok(Operation::Info)
        }
        "build" => {
            if args.len() != BUILD_ARGUMENT_COUNT {
                return Err(PolicyError::UnexpectedArguments {
                    command: command.clone(),
                });
            }
            let name = args[1].clone();
            validate_machine_name(&name)?;
            if declared.binary_search(&name).is_err() {
                return Err(PolicyError::UndeclaredMachine { name });
            }
            Ok(Operation::Build { name })
        }
        "deploy" | "install" => Err(PolicyError::DestructiveCommand {
            command: command.clone(),
        }),
        _ => Err(PolicyError::UnsupportedCommand {
            command: command.clone(),
        }),
    }
}

#[must_use]
pub fn invocation(operation: &Operation) -> Invocation {
    let args = match operation {
        Operation::Info => vec!["machines".to_owned(), "info".to_owned()],
        Operation::Build { name } => vec!["build".to_owned(), format!("machines.{name}")],
    };
    Invocation { args }
}

pub fn classify_child_exit(code: Option<i32>) -> Result<(), PolicyError> {
    if code == Some(0) {
        Ok(())
    } else {
        Err(PolicyError::ChildFailed { code })
    }
}

fn validate_machine_name(name: &str) -> Result<(), PolicyError> {
    let Some(first) = name.bytes().next() else {
        return Err(PolicyError::InvalidMachineName {
            name: name.to_owned(),
            reason: MACHINE_NAME_FIRST_MESSAGE,
        });
    };
    if !(first.is_ascii_alphabetic() || first == b'_') {
        return Err(PolicyError::InvalidMachineName {
            name: name.to_owned(),
            reason: MACHINE_NAME_FIRST_MESSAGE,
        });
    }
    if !name
        .bytes()
        .all(|byte| byte.is_ascii_alphanumeric() || byte == b'_' || byte == b'-')
    {
        return Err(PolicyError::InvalidMachineName {
            name: name.to_owned(),
            reason: MACHINE_NAME_REST_MESSAGE,
        });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn strings(values: &[&str]) -> Vec<String> {
        values.iter().map(|value| (*value).to_owned()).collect()
    }

    #[test]
    fn info_maps_to_read_only_devenv_command() {
        let operation = parse_operation(&strings(&["info"]), &[]).expect("info must parse");
        assert_eq!(operation, Operation::Info);
        assert_eq!(invocation(&operation).args, strings(&["machines", "info"]));
    }

    #[test]
    fn declared_build_maps_to_devenv_build_target() {
        let declared = strings(&["fixture-dgx"]);
        let operation = parse_operation(&strings(&["build", "fixture-dgx"]), &declared)
            .expect("declared build must parse");
        assert_eq!(
            invocation(&operation).args,
            strings(&["build", "machines.fixture-dgx"])
        );
    }

    #[test]
    fn declared_names_are_sorted_and_deduplicated() {
        assert_eq!(
            declared_names("zeta\nalpha\nzeta\n"),
            strings(&["alpha", "zeta"])
        );
    }

    #[test]
    fn destructive_commands_fail_before_invocation() {
        for command in ["deploy", "install"] {
            let error = parse_operation(&strings(&[command]), &[]).expect_err("must reject");
            assert_eq!(
                error,
                PolicyError::DestructiveCommand {
                    command: command.to_owned()
                }
            );
            assert!(error.to_string().contains("authorized Cairn change"));
        }
    }

    #[test]
    fn undeclared_and_invalid_machine_names_fail() {
        assert_eq!(
            parse_operation(&strings(&["build", "missing"]), &[]),
            Err(PolicyError::UndeclaredMachine {
                name: "missing".to_owned()
            })
        );
        assert!(matches!(
            parse_operation(&strings(&["build", "bad.name"]), &[]),
            Err(PolicyError::InvalidMachineName { .. })
        ));
        assert!(matches!(
            parse_operation(&strings(&["build", "-bad"]), &[]),
            Err(PolicyError::InvalidMachineName { .. })
        ));
    }

    #[test]
    fn missing_unknown_and_extra_arguments_fail() {
        assert_eq!(parse_operation(&[], &[]), Err(PolicyError::MissingCommand));
        assert!(matches!(
            parse_operation(&strings(&["status"]), &[]),
            Err(PolicyError::UnsupportedCommand { .. })
        ));
        assert!(matches!(
            parse_operation(&strings(&["info", "extra"]), &[]),
            Err(PolicyError::UnexpectedArguments { .. })
        ));
        assert!(matches!(
            parse_operation(&strings(&["build"]), &[]),
            Err(PolicyError::UnexpectedArguments { .. })
        ));
    }

    #[test]
    fn child_process_errors_remain_errors() {
        const FIXTURE_FAILURE_CODE: i32 = 9;

        assert_eq!(classify_child_exit(Some(0)), Ok(()));
        assert_eq!(
            classify_child_exit(Some(FIXTURE_FAILURE_CODE)),
            Err(PolicyError::ChildFailed {
                code: Some(FIXTURE_FAILURE_CODE)
            })
        );
        assert_eq!(
            classify_child_exit(None),
            Err(PolicyError::ChildFailed { code: None })
        );
    }
}
