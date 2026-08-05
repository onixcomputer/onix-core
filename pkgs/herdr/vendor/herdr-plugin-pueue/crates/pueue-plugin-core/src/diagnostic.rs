use crate::{sanitize_terminal_text, ControlOperation, MAX_DIAGNOSTIC_TEXT_COLUMNS};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Operation {
    HerdrPopup,
    HerdrSplit,
    HerdrMetadata,
    PueueVersion,
    PueueStatus,
    PueueControl(ControlOperation),
    PueueSendInput,
    Terminal,
}

impl Operation {
    pub const fn label(self) -> &'static str {
        match self {
            Self::HerdrPopup => "Herdr popup",
            Self::HerdrSplit => "Herdr split",
            Self::HerdrMetadata => "Herdr metadata",
            Self::PueueVersion => "Pueue version",
            Self::PueueStatus => "Pueue status",
            Self::PueueControl(operation) => operation.label(),
            Self::PueueSendInput => "Pueue send input",
            Self::Terminal => "terminal",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FailureClass {
    InvalidHerdrPath,
    InvalidHerdrContext,
    MissingExecutable,
    PermissionDenied,
    SpawnFailed,
    ProcessPipeUnavailable,
    ProcessWaitFailed,
    ProcessOutputReadFailed,
    ProcessOutputThreadFailed,
    DaemonUnavailable,
    Timeout,
    StdoutLimit,
    StderrLimit,
    NonzeroExit,
    InvalidUtf8,
    UnsupportedVersion,
    InvalidData,
    ControlRejected,
    TerminalUnavailable,
}

impl FailureClass {
    pub const fn label(self) -> &'static str {
        match self {
            Self::InvalidHerdrPath => "invalid Herdr path",
            Self::InvalidHerdrContext => "invalid Herdr context",
            Self::MissingExecutable => "missing executable",
            Self::PermissionDenied => "permission denied",
            Self::SpawnFailed => "process spawn failed",
            Self::ProcessPipeUnavailable => "process pipe unavailable",
            Self::ProcessWaitFailed => "process wait failed",
            Self::ProcessOutputReadFailed => "process output read failed",
            Self::ProcessOutputThreadFailed => "process output thread failed",
            Self::DaemonUnavailable => "daemon unavailable",
            Self::Timeout => "timeout",
            Self::StdoutLimit => "stdout limit exceeded",
            Self::StderrLimit => "stderr limit exceeded",
            Self::NonzeroExit => "nonzero exit",
            Self::InvalidUtf8 => "invalid UTF-8",
            Self::UnsupportedVersion => "unsupported version",
            Self::InvalidData => "invalid data",
            Self::ControlRejected => "control rejected",
            Self::TerminalUnavailable => "terminal unavailable",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Diagnostic {
    pub operation: Operation,
    pub class: FailureClass,
}

impl Diagnostic {
    pub const fn new(operation: Operation, class: FailureClass) -> Self {
        Self { operation, class }
    }

    pub fn message(self) -> String {
        let message = format!("{} failed: {}", self.operation.label(), self.class.label());
        sanitize_terminal_text(&message, MAX_DIAGNOSTIC_TEXT_COLUMNS)
    }
}

impl std::fmt::Display for Diagnostic {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(&self.message())
    }
}

impl std::error::Error for Diagnostic {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn diagnostic_identifies_operation_and_failure_class() {
        let diagnostic = Diagnostic::new(Operation::PueueStatus, FailureClass::Timeout);
        assert_eq!(diagnostic.message(), "Pueue status failed: timeout");
        assert!(u32::try_from(diagnostic.message().len())
            .is_ok_and(|length| length <= MAX_DIAGNOSTIC_TEXT_COLUMNS));
    }
}
