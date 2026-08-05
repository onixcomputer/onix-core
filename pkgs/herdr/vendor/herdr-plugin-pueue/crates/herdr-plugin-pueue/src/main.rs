#![forbid(unsafe_code)]

use std::process::ExitCode;

use herdr_plugin_pueue::{run_dashboard, run_open_dashboard, run_open_split_dashboard};

const USAGE: &str = "Usage: herdr-plugin-pueue <open-dashboard|open-dashboard-split|dashboard>";

fn main() -> ExitCode {
    let arguments = std::env::args().skip(1).collect::<Vec<_>>();
    match run(&arguments) {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("{message}");
            ExitCode::FAILURE
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Mode {
    OpenPopup,
    OpenSplit,
    Dashboard,
    Help,
}

fn parse_mode(arguments: &[String]) -> Result<Mode, String> {
    match arguments {
        [mode] if mode == "open-dashboard" => Ok(Mode::OpenPopup),
        [mode] if mode == "open-dashboard-split" => Ok(Mode::OpenSplit),
        [mode] if mode == "dashboard" => Ok(Mode::Dashboard),
        [flag] if flag == "--help" || flag == "-h" => Ok(Mode::Help),
        _ => Err(USAGE.to_string()),
    }
}

fn run(arguments: &[String]) -> Result<(), String> {
    match parse_mode(arguments)? {
        Mode::OpenPopup => run_open_dashboard().map_err(|error| error.message()),
        Mode::OpenSplit => run_open_split_dashboard().map_err(|error| error.message()),
        Mode::Dashboard => run_dashboard().map_err(|error| error.message()),
        Mode::Help => {
            println!("{USAGE}");
            Ok(())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_popup_split_and_direct_modes() {
        // r[verify herdr.pueue_plugin.dashboard.direct]
        assert_eq!(
            parse_mode(&["open-dashboard".to_string()]),
            Ok(Mode::OpenPopup)
        );
        assert_eq!(
            parse_mode(&["open-dashboard-split".to_string()]),
            Ok(Mode::OpenSplit)
        );
        assert_eq!(parse_mode(&["dashboard".to_string()]), Ok(Mode::Dashboard));
    }

    #[test]
    fn rejects_missing_and_unknown_modes() {
        assert_eq!(parse_mode(&[]), Err(USAGE.to_string()));
        assert_eq!(parse_mode(&["unknown".to_string()]), Err(USAGE.to_string()));
    }

    #[test]
    fn prints_help_without_external_effects() {
        assert_eq!(run(&["--help".to_string()]), Ok(()));
    }
}
