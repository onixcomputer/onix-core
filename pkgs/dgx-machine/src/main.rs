use std::env;
use std::process::{Command, ExitCode};

use dgx_machine::{classify_child_exit, declared_names, invocation, parse_operation};

const EXIT_ERROR: u8 = 1;
const DEVENV_BIN_ENV: &str = "DGX_DEVENV_BIN";
const MACHINE_NAMES_ENV: &str = "DGX_MACHINE_NAMES";

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let devenv_bin = env::var(DEVENV_BIN_ENV)
        .map_err(|_| format!("{DEVENV_BIN_ENV} is not set by the Nix wrapper"))?;
    let declared = declared_names(&env::var(MACHINE_NAMES_ENV).unwrap_or_default());
    let args: Vec<String> = env::args().skip(1).collect();
    let operation = parse_operation(&args, &declared)?;
    let plan = invocation(&operation);

    let status = Command::new(devenv_bin).args(&plan.args).status()?;
    classify_child_exit(status.code())?;
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("dgx-machine: {error}");
            ExitCode::from(EXIT_ERROR)
        }
    }
}
