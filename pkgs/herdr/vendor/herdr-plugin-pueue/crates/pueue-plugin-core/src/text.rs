use unicode_width::UnicodeWidthChar;

const ESCAPE: char = '\u{001b}';
const BELL: char = '\u{0007}';
const CONTROL_SEQUENCE_INTRODUCER: char = '\u{009b}';
const OPERATING_SYSTEM_COMMAND: char = '\u{009d}';
const STRING_TERMINATOR: char = '\u{009c}';
const ELLIPSIS: char = '…';
const ELLIPSIS_COLUMNS: u32 = 1;
const MAX_OUTPUT_CHARACTERS_PER_COLUMN: u32 = 4;
const ENV_PROGRAM: &str = "env";
const UNLABELED_TASK_DESCRIPTION: &str = "unlabeled task";
const SHELL_CHAIN_MARKERS: &[&str] = &["&&", "||", ";"];
const MAX_ENVIRONMENT_PREFIX_TOKENS: usize = 256;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct TextBounds {
    columns: u32,
    characters: u32,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
enum EscapeState {
    #[default]
    Ground,
    Escape,
    EscapeIntermediate,
    ControlSequence,
    ControlString,
    ControlStringEscape,
}

pub fn sanitize_terminal_text(input: &str, max_columns: u32) -> String {
    // r[impl herdr.pueue_plugin.security.terminal]
    if max_columns == 0 {
        return String::new();
    }
    let bounds = TextBounds {
        columns: max_columns,
        characters: max_columns.saturating_mul(MAX_OUTPUT_CHARACTERS_PER_COLUMN),
    };
    let max_capacity = match usize::try_from(bounds.characters) {
        Ok(max_capacity) => max_capacity,
        Err(_) => input.len(),
    };
    let mut output = String::with_capacity(input.len().min(max_capacity));
    let mut columns = 0u32;
    let mut output_characters = 0u32;
    let mut state = EscapeState::Ground;
    let mut was_truncated = false;
    for character in input.chars() {
        let next_state = consume_escape_state(state, character);
        if state != EscapeState::Ground || next_state != EscapeState::Ground {
            state = next_state;
            continue;
        }
        if character == ESCAPE || character == CONTROL_SEQUENCE_INTRODUCER {
            state = consume_escape_state(state, character);
            continue;
        }
        if character.is_control() {
            if character.is_whitespace() {
                append_space(&mut output, &mut columns, &mut output_characters, bounds);
            }
            continue;
        }
        let width = display_width(character);
        if columns.saturating_add(width) > bounds.columns {
            was_truncated = true;
            break;
        }
        if output_characters >= bounds.characters {
            was_truncated = true;
            break;
        }
        output.push(character);
        columns = columns.saturating_add(width);
        output_characters = output_characters.saturating_add(1);
    }
    if was_truncated {
        append_ellipsis(&mut output, &mut columns, &mut output_characters, bounds);
    }
    output.trim().to_string()
}

pub(crate) fn sanitize_command_description(command: &str, max_columns: u32) -> String {
    let Some(first) = command.split_whitespace().next() else {
        return UNLABELED_TASK_DESCRIPTION.to_string();
    };
    if first == ENV_PROGRAM || environment_assignment(first) {
        return environment_wrapped_program(command);
    }
    let bounded_command = sanitize_terminal_text(command, max_columns);
    let tokens = bounded_command.split_whitespace().collect::<Vec<_>>();
    let sensitive_index = tokens
        .iter()
        .position(|token| *token == ENV_PROGRAM || token.contains('='));
    match sensitive_index {
        Some(index) => command_prefix(&tokens[..index]),
        None => bounded_command,
    }
}

fn environment_wrapped_program(command: &str) -> String {
    for token in command
        .split_whitespace()
        .take(MAX_ENVIRONMENT_PREFIX_TOKENS)
    {
        if token == ENV_PROGRAM || token.contains('=') {
            continue;
        }
        return safe_program_name(token)
            .unwrap_or(UNLABELED_TASK_DESCRIPTION)
            .to_string();
    }
    UNLABELED_TASK_DESCRIPTION.to_string()
}

fn command_prefix(tokens: &[&str]) -> String {
    let mut end = tokens.len();
    while end > 0 && SHELL_CHAIN_MARKERS.contains(&tokens[end - 1]) {
        end = end.saturating_sub(1);
    }
    if end == 0 {
        return UNLABELED_TASK_DESCRIPTION.to_string();
    }
    tokens[..end].join(" ")
}

fn environment_assignment(token: &str) -> bool {
    let Some((name, _value)) = token.split_once('=') else {
        return false;
    };
    let mut characters = name.chars();
    let Some(first) = characters.next() else {
        return false;
    };
    if !first.is_ascii_alphabetic() && first != '_' {
        return false;
    }
    characters.all(|character| character.is_ascii_alphanumeric() || character == '_')
}

fn safe_program_name(token: &str) -> Option<&str> {
    if token.starts_with('-') {
        return None;
    }
    let is_safe = token
        .chars()
        .all(|character| character.is_ascii_alphanumeric() || "._/+-".contains(character));
    if !is_safe {
        return None;
    }
    let name = token.rsplit('/').next()?;
    if name.is_empty() || matches!(name, "." | "..") {
        return None;
    }
    Some(name)
}

fn consume_escape_state(state: EscapeState, character: char) -> EscapeState {
    match state {
        EscapeState::Ground => match character {
            ESCAPE => EscapeState::Escape,
            CONTROL_SEQUENCE_INTRODUCER => EscapeState::ControlSequence,
            OPERATING_SYSTEM_COMMAND => EscapeState::ControlString,
            _ => EscapeState::Ground,
        },
        EscapeState::Escape => match character {
            '[' => EscapeState::ControlSequence,
            ']' | 'P' | '^' | '_' => EscapeState::ControlString,
            '\u{0020}'..='\u{002f}' => EscapeState::EscapeIntermediate,
            _ => EscapeState::Ground,
        },
        EscapeState::EscapeIntermediate => match character {
            '\u{0030}'..='\u{007e}' => EscapeState::Ground,
            _ => EscapeState::EscapeIntermediate,
        },
        EscapeState::ControlSequence => match character {
            '\u{0040}'..='\u{007e}' => EscapeState::Ground,
            _ => EscapeState::ControlSequence,
        },
        EscapeState::ControlString => match character {
            BELL | STRING_TERMINATOR => EscapeState::Ground,
            ESCAPE => EscapeState::ControlStringEscape,
            _ => EscapeState::ControlString,
        },
        EscapeState::ControlStringEscape => match character {
            '\\' => EscapeState::Ground,
            ESCAPE => EscapeState::ControlStringEscape,
            _ => EscapeState::ControlString,
        },
    }
}

fn append_space(
    output: &mut String,
    columns: &mut u32,
    output_characters: &mut u32,
    bounds: TextBounds,
) {
    if output.is_empty() || output.ends_with(' ') || *columns >= bounds.columns {
        return;
    }
    if *output_characters >= bounds.characters {
        return;
    }
    output.push(' ');
    *columns = columns.saturating_add(1);
    *output_characters = output_characters.saturating_add(1);
}

fn append_ellipsis(
    output: &mut String,
    columns: &mut u32,
    output_characters: &mut u32,
    bounds: TextBounds,
) {
    while columns.saturating_add(ELLIPSIS_COLUMNS) > bounds.columns
        || *output_characters >= bounds.characters
    {
        let Some(character) = output.pop() else {
            return;
        };
        *columns = columns.saturating_sub(display_width(character));
        *output_characters = output_characters.saturating_sub(1);
    }
    while output.ends_with(' ') {
        output.pop();
        *columns = columns.saturating_sub(1);
        *output_characters = output_characters.saturating_sub(1);
    }
    output.push(ELLIPSIS);
    *output_characters = output_characters.saturating_add(1);
}

fn display_width(character: char) -> u32 {
    UnicodeWidthChar::width(character)
        .and_then(|width| u32::try_from(width).ok())
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    const SHORT_BOUND_COLUMNS: u32 = 5;
    const PLAIN_TEXT_BOUND_COLUMNS: u32 = 40;
    const HOSTILE_TEXT_BOUND_COLUMNS: u32 = 80;
    const EXCESS_OUTPUT_CHARACTERS: u32 = 1;

    #[test]
    fn preserves_plain_unicode_text() {
        assert_eq!(
            sanitize_terminal_text("build λ", PLAIN_TEXT_BOUND_COLUMNS),
            "build λ"
        );
    }

    #[test]
    fn removes_terminal_controls_and_control_payloads() {
        // r[verify herdr.pueue_plugin.security.terminal]
        let hostile = "ok\u{001b}[31mred\u{001b}[0m\u{001b}]0;secret\u{0007} done\nnext";
        let sanitized = sanitize_terminal_text(hostile, HOSTILE_TEXT_BOUND_COLUMNS);
        assert_eq!(sanitized, "okred done next");
        assert!(!sanitized.contains("secret"));
        assert!(!sanitized.contains(ESCAPE));
    }

    #[test]
    fn applies_the_display_bound() {
        assert_eq!(
            sanitize_terminal_text("abcdefgh", SHORT_BOUND_COLUMNS),
            "abcd…"
        );
        assert_eq!(sanitize_terminal_text("anything", 0), "");
    }

    #[test]
    fn bounds_zero_width_unicode_by_character_count() -> Result<(), Box<dyn std::error::Error>> {
        let maximum_characters =
            SHORT_BOUND_COLUMNS.saturating_mul(MAX_OUTPUT_CHARACTERS_PER_COLUMN);
        let input_characters = maximum_characters.saturating_add(EXCESS_OUTPUT_CHARACTERS);
        let input = "\u{0301}".repeat(usize::try_from(input_characters)?);

        let sanitized = sanitize_terminal_text(&input, SHORT_BOUND_COLUMNS);

        assert_eq!(
            sanitized.chars().count(),
            usize::try_from(maximum_characters)?
        );
        assert!(sanitized.ends_with(ELLIPSIS));
        Ok(())
    }
}
