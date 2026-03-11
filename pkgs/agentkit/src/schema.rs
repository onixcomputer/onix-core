//! Universal skill schema for AI agents.
//!
//! This module defines the universal SKILL.md format that works across
//! multiple AI agents including Claude, OpenAI Codex, Cursor, and others.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Universal capability names that map to agent-specific tools.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Capability {
    /// Read file contents
    ReadFiles,
    /// Create or modify files
    WriteFiles,
    /// Make targeted edits to files
    EditFiles,
    /// Execute shell commands
    Execute,
    /// Search within codebase
    SearchCode,
    /// Find files by pattern
    Glob,
    /// Search the internet
    SearchWeb,
    /// Fetch web content
    FetchUrl,
    /// Spawn sub-agents for complex tasks
    Task,
}

impl Capability {
    /// Get the Claude-specific tool name for this capability.
    pub fn claude_tool(&self) -> &'static str {
        match self {
            Self::ReadFiles => "Read",
            Self::WriteFiles => "Write",
            Self::EditFiles => "Edit",
            Self::Execute => "Bash",
            Self::SearchCode => "Grep",
            Self::Glob => "Glob",
            Self::SearchWeb => "WebSearch",
            Self::FetchUrl => "WebFetch",
            Self::Task => "Task",
        }
    }

    /// Get the OpenAI Codex tool name for this capability.
    pub fn openai_tool(&self) -> &'static str {
        match self {
            Self::ReadFiles => "file_read",
            Self::WriteFiles => "file_write",
            Self::EditFiles => "file_edit",
            Self::Execute => "shell",
            Self::SearchCode => "file_search",
            Self::Glob => "file_search",
            Self::SearchWeb => "web_search",
            Self::FetchUrl => "fetch",
            Self::Task => "multi_tool_use",
        }
    }

    /// Get the Cursor tool name for this capability.
    pub fn cursor_tool(&self) -> &'static str {
        match self {
            Self::ReadFiles => "read_file",
            Self::WriteFiles => "write_file",
            Self::EditFiles => "edit_file",
            Self::Execute => "terminal",
            Self::SearchCode => "search",
            Self::Glob => "glob",
            Self::SearchWeb => "web",
            Self::FetchUrl => "fetch",
            Self::Task => "agent",
        }
    }

    /// Get the Pi tool name for this capability.
    pub fn pi_tool(&self) -> &'static str {
        match self {
            Self::ReadFiles => "read_file",
            Self::WriteFiles => "write_file",
            Self::EditFiles => "edit_file",
            Self::Execute => "shell",
            Self::SearchCode => "search",
            Self::Glob => "glob",
            Self::SearchWeb => "web_search",
            Self::FetchUrl => "fetch",
            Self::Task => "agent",
        }
    }

    /// Get the Goose tool name for this capability.
    pub fn goose_tool(&self) -> &'static str {
        match self {
            Self::ReadFiles => "read_file",
            Self::WriteFiles => "write_file",
            Self::EditFiles => "text_editor",
            Self::Execute => "shell",
            Self::SearchCode => "search",
            Self::Glob => "list_directory",
            Self::SearchWeb => "web_search",
            Self::FetchUrl => "fetch",
            Self::Task => "platform__read_skill",
        }
    }
}

/// Claude-specific configuration.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub struct ClaudeConfig {
    /// Model to use (sonnet, opus, haiku, or inherit).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,

    /// Allowed tools (Claude-specific names).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tools: Option<Vec<String>>,

    /// Whether this skill is disabled for Claude.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub disabled: bool,
}

/// OpenAI Codex-specific configuration.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub struct OpenAIConfig {
    /// Model to use.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,

    /// Whether this skill is disabled for OpenAI.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub disabled: bool,
}

/// Cursor-specific configuration.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub struct CursorConfig {
    /// Activation mode: auto, manual, always.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub activation: Option<String>,

    /// File globs for auto-activation.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub globs: Option<Vec<String>>,

    /// Whether this skill is disabled for Cursor.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub disabled: bool,
}

/// Pi-specific configuration.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub struct PiConfig {
    /// Model to use (provider/model format, e.g. "anthropic/claude-sonnet-4-20250514").
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,

    /// Whether this skill is disabled for Pi.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub disabled: bool,
}

/// Goose-specific configuration.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub struct GooseConfig {
    /// Model to use (provider/model format).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,

    /// Whether this skill is disabled for Goose.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub disabled: bool,
}

/// Agent-specific configurations.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub struct AgentConfigs {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub claude: Option<ClaudeConfig>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub openai: Option<OpenAIConfig>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub cursor: Option<CursorConfig>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub pi: Option<PiConfig>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub goose: Option<GooseConfig>,

    /// Additional agent configurations (for extensibility).
    #[serde(flatten)]
    pub other: HashMap<String, serde_yaml::Value>,
}

/// Universal skill metadata (YAML frontmatter).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub struct SkillMeta {
    /// Skill identifier (required).
    pub name: String,

    /// Description of when to use this skill (required).
    pub description: String,

    /// Semantic version.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<String>,

    /// License identifier.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub license: Option<String>,

    /// Author name or handle.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub author: Option<String>,

    /// Universal capabilities (abstract tool names).
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub capabilities: Vec<Capability>,

    /// Agent-specific configuration overrides.
    #[serde(default, skip_serializing_if = "is_default_agent_configs")]
    pub agents: AgentConfigs,

    /// Tags for organization/filtering.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,

    // Legacy Claude-specific fields (for backwards compatibility)
    /// Legacy: Claude model override.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,

    /// Legacy: Claude allowed-tools.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub allowed_tools: Option<String>,
}

fn is_default_agent_configs(configs: &AgentConfigs) -> bool {
    configs.claude.is_none()
        && configs.openai.is_none()
        && configs.cursor.is_none()
        && configs.pi.is_none()
        && configs.goose.is_none()
        && configs.other.is_empty()
}

impl SkillMeta {
    /// Check if this skill uses the legacy Claude-only format.
    pub fn is_legacy_format(&self) -> bool {
        self.model.is_some() || self.allowed_tools.is_some()
    }

    /// Get Claude configuration, merging legacy fields if present.
    pub fn claude_config(&self) -> ClaudeConfig {
        let mut config = self.agents.claude.clone().unwrap_or_default();

        // Merge legacy fields
        if config.model.is_none() {
            config.model = self.model.clone();
        }
        if config.tools.is_none() {
            if let Some(ref tools) = self.allowed_tools {
                config.tools = Some(tools.split(',').map(|s| s.trim().to_string()).collect());
            }
        }

        config
    }

    /// Get tools for Claude, either from explicit config or capabilities.
    pub fn claude_tools(&self) -> Vec<String> {
        let config = self.claude_config();
        if let Some(tools) = config.tools {
            return tools;
        }

        // Map capabilities to Claude tools
        self.capabilities
            .iter()
            .map(|c| c.claude_tool().to_string())
            .collect()
    }
}

/// A complete skill including metadata and content.
#[derive(Debug, Clone)]
pub struct Skill {
    /// Skill metadata from YAML frontmatter.
    pub meta: SkillMeta,

    /// Markdown content (instructions).
    pub content: String,

    /// Source file path.
    pub source_path: Option<std::path::PathBuf>,
}

impl Skill {
    /// Parse a SKILL.md file into a Skill struct.
    pub fn parse(input: &str) -> Result<Self, SkillParseError> {
        let (meta, content) = parse_frontmatter(input)?;
        Ok(Self {
            meta,
            content,
            source_path: None,
        })
    }

    /// Parse a SKILL.md file with source path.
    pub fn parse_with_path(input: &str, path: std::path::PathBuf) -> Result<Self, SkillParseError> {
        let mut skill = Self::parse(input)?;
        skill.source_path = Some(path);
        Ok(skill)
    }

    /// Export to Claude SKILL.md format.
    pub fn to_claude_format(&self) -> String {
        let mut frontmatter = format!(
            "---\nname: {}\ndescription: {}",
            self.meta.name, self.meta.description
        );

        let config = self.meta.claude_config();
        if let Some(ref model) = config.model {
            frontmatter.push_str(&format!("\nmodel: {model}"));
        }
        if let Some(ref tools) = config.tools {
            frontmatter.push_str(&format!("\nallowed-tools: {}", tools.join(", ")));
        }

        frontmatter.push_str("\n---\n");
        frontmatter.push_str(&self.content);
        frontmatter
    }

    /// Export to Cursor .mdc format.
    pub fn to_cursor_format(&self) -> String {
        let cursor = self.meta.agents.cursor.clone().unwrap_or_default();
        let mut frontmatter = format!("---\ndescription: {}", self.meta.description);

        if let Some(ref globs) = cursor.globs {
            frontmatter.push_str(&format!(
                "\nglobs: [{}]",
                globs
                    .iter()
                    .map(|g| format!("\"{g}\""))
                    .collect::<Vec<_>>()
                    .join(", ")
            ));
        }

        let always_apply = cursor.activation.as_deref() == Some("always");
        frontmatter.push_str(&format!("\nalwaysApply: {always_apply}"));
        frontmatter.push_str("\n---\n");
        frontmatter.push_str(&self.content);
        frontmatter
    }

    /// Export to generic AGENTS.md format (plain markdown).
    pub fn to_agents_md_format(&self) -> String {
        format!(
            "# {}\n\n{}\n\n{}",
            self.meta.name, self.meta.description, self.content
        )
    }
}

/// Error type for skill parsing.
#[derive(Debug, thiserror::Error)]
pub enum SkillParseError {
    #[error("Missing YAML frontmatter (expected --- delimiters)")]
    MissingFrontmatter,

    #[error("Invalid YAML frontmatter: {0}")]
    InvalidYaml(#[from] serde_yaml::Error),

    #[error("Missing required field: {0}")]
    MissingField(&'static str),
}

/// Parse YAML frontmatter from markdown content.
fn parse_frontmatter(input: &str) -> Result<(SkillMeta, String), SkillParseError> {
    let input = input.trim();

    if !input.starts_with("---") {
        return Err(SkillParseError::MissingFrontmatter);
    }

    let rest = &input[3..];
    let end_pos = rest
        .find("\n---")
        .ok_or(SkillParseError::MissingFrontmatter)?;

    let yaml = &rest[..end_pos];
    let content = &rest[end_pos + 4..];

    let meta: SkillMeta = serde_yaml::from_str(yaml)?;

    Ok((meta, content.trim().to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_minimal_skill() {
        let input = r#"---
name: test-skill
description: A test skill
---

# Instructions

Do something useful.
"#;

        let skill = Skill::parse(input).unwrap();
        assert_eq!(skill.meta.name, "test-skill");
        assert_eq!(skill.meta.description, "A test skill");
        assert!(skill.content.contains("Do something useful"));
    }

    #[test]
    fn test_parse_legacy_claude_format() {
        let input = r#"---
name: ultra-mode
description: Maximum capability mode
model: claude-opus-4-5-20251101
allowed-tools: Task, WebSearch, Read
---

# Ultra Mode

Be awesome.
"#;

        let skill = Skill::parse(input).unwrap();
        assert!(skill.meta.is_legacy_format());

        let config = skill.meta.claude_config();
        assert_eq!(config.model.as_deref(), Some("claude-opus-4-5-20251101"));
        assert_eq!(
            config.tools,
            Some(vec![
                "Task".to_string(),
                "WebSearch".to_string(),
                "Read".to_string()
            ])
        );
    }

    #[test]
    fn test_parse_universal_format() {
        let input = r#"---
name: universal-skill
description: Works everywhere
version: 1.0.0
capabilities:
  - read_files
  - write_files
  - execute
agents:
  claude:
    model: opus
  cursor:
    activation: auto
    globs:
      - "*.rs"
      - "*.py"
---

# Universal Skill

Works on all agents.
"#;

        let skill = Skill::parse(input).unwrap();
        assert!(!skill.meta.is_legacy_format());
        assert_eq!(skill.meta.capabilities.len(), 3);
        assert!(skill.meta.agents.claude.is_some());
        assert!(skill.meta.agents.cursor.is_some());
    }

    #[test]
    fn test_capability_tool_mapping() {
        assert_eq!(Capability::ReadFiles.claude_tool(), "Read");
        assert_eq!(Capability::ReadFiles.openai_tool(), "file_read");
        assert_eq!(Capability::ReadFiles.cursor_tool(), "read_file");

        assert_eq!(Capability::Execute.claude_tool(), "Bash");
        assert_eq!(Capability::Execute.openai_tool(), "shell");
        assert_eq!(Capability::Execute.cursor_tool(), "terminal");
    }

    #[test]
    fn test_export_claude_format() {
        let input = r#"---
name: test
description: Test skill
capabilities:
  - read_files
agents:
  claude:
    model: opus
---

Instructions here.
"#;

        let skill = Skill::parse(input).unwrap();
        let output = skill.to_claude_format();

        assert!(output.contains("name: test"));
        assert!(output.contains("model: opus"));
    }

    #[test]
    fn test_export_cursor_format() {
        let input = r#"---
name: test
description: Test skill
agents:
  cursor:
    activation: always
    globs:
      - "*.rs"
---

Instructions here.
"#;

        let skill = Skill::parse(input).unwrap();
        let output = skill.to_cursor_format();

        assert!(output.contains("description: Test skill"));
        assert!(output.contains("alwaysApply: true"));
        assert!(output.contains("globs:"));
    }
}
