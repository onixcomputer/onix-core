//! AgentKit configuration for managing agent homes and tool mappings.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;

/// Agent home directory configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentHome {
    /// Home directory path (supports ~ expansion).
    pub home: PathBuf,

    /// Directory name for skills within home.
    #[serde(default = "default_skill_dir")]
    pub skill_dir: String,

    /// Directory name for commands within home.
    #[serde(default = "default_command_dir")]
    pub command_dir: String,

    /// Main instruction file name.
    #[serde(default)]
    pub instruction_file: Option<String>,

    /// Whether this agent uses .mdc format (Cursor).
    #[serde(default)]
    pub uses_mdc: bool,
}

fn default_skill_dir() -> String {
    "skills".to_string()
}

fn default_command_dir() -> String {
    "commands".to_string()
}

/// Tool name mapping from universal capability to agent-specific tool.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ToolMapping {
    pub claude: Option<String>,
    pub openai: Option<String>,
    pub cursor: Option<String>,
    #[serde(flatten)]
    pub other: HashMap<String, String>,
}

/// AgentKit configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    /// Central repository path.
    #[serde(default = "default_repo_path")]
    pub repo_path: PathBuf,

    /// Git remote URL for syncing the central repo across machines.
    /// Can also be set via AGENTKIT_REMOTE or CLAUDE_MD_REMOTE env vars.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub remote: Option<String>,

    /// Agent home configurations.
    #[serde(default = "default_agents")]
    pub agents: HashMap<String, AgentHome>,

    /// Tool mappings from universal names to agent-specific names.
    #[serde(default)]
    pub tool_mappings: HashMap<String, ToolMapping>,
}

fn default_repo_path() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("~"))
        .join("git")
        .join("claude.md")
}

fn default_agents() -> HashMap<String, AgentHome> {
    let mut agents = HashMap::new();

    agents.insert(
        "claude".to_string(),
        AgentHome {
            home: PathBuf::from("~/.claude"),
            skill_dir: "skills".to_string(),
            command_dir: "commands".to_string(),
            instruction_file: Some("CLAUDE.md".to_string()),
            uses_mdc: false,
        },
    );

    agents.insert(
        "openai".to_string(),
        AgentHome {
            home: PathBuf::from("~/.codex"),
            skill_dir: "skills".to_string(),
            command_dir: "commands".to_string(),
            instruction_file: Some("AGENTS.md".to_string()),
            uses_mdc: false,
        },
    );

    agents.insert(
        "cursor".to_string(),
        AgentHome {
            home: PathBuf::from(".cursor/rules"),
            skill_dir: ".".to_string(),
            command_dir: ".".to_string(),
            instruction_file: None,
            uses_mdc: true,
        },
    );

    agents.insert(
        "pi".to_string(),
        AgentHome {
            home: PathBuf::from("~/.pi/agent"),
            skill_dir: "skills".to_string(),
            command_dir: "commands".to_string(),
            instruction_file: Some("AGENTS.md".to_string()),
            uses_mdc: false,
        },
    );

    agents.insert(
        "goose".to_string(),
        AgentHome {
            home: PathBuf::from("~/.config/goose"),
            skill_dir: "skills".to_string(),
            command_dir: "commands".to_string(),
            instruction_file: None,
            uses_mdc: false,
        },
    );

    agents
}

impl Default for Config {
    fn default() -> Self {
        Self {
            repo_path: default_repo_path(),
            remote: None,
            agents: default_agents(),
            tool_mappings: HashMap::new(),
        }
    }
}

impl Config {
    /// Load configuration from file, or return defaults.
    /// Also checks AGENTKIT_REMOTE and CLAUDE_MD_REMOTE env vars for remote.
    pub fn load() -> anyhow::Result<Self> {
        let config_path = Self::config_path();

        let mut config = if config_path.exists() {
            let content = std::fs::read_to_string(&config_path)?;
            toml::from_str(&content)?
        } else {
            Self::default()
        };

        // Check env vars for remote (env overrides config file)
        if let Ok(remote) = std::env::var("AGENTKIT_REMOTE") {
            config.remote = Some(remote);
        } else if let Ok(remote) = std::env::var("CLAUDE_MD_REMOTE") {
            config.remote = Some(remote);
        }

        Ok(config)
    }

    /// Save configuration to file.
    pub fn save(&self) -> anyhow::Result<()> {
        let config_path = Self::config_path();

        if let Some(parent) = config_path.parent() {
            std::fs::create_dir_all(parent)?;
        }

        let content = toml::to_string_pretty(self)?;
        std::fs::write(&config_path, content)?;

        Ok(())
    }

    /// Get the configuration file path.
    pub fn config_path() -> PathBuf {
        dirs::config_dir()
            .unwrap_or_else(|| PathBuf::from("~/.config"))
            .join("agentkit")
            .join("config.toml")
    }

    /// Expand ~ in a path.
    pub fn expand_path(path: &PathBuf) -> PathBuf {
        let path_str = path.to_string_lossy();
        if path_str.starts_with("~/") {
            if let Some(home) = dirs::home_dir() {
                return home.join(&path_str[2..]);
            }
        }
        path.clone()
    }

    /// Get the expanded repo path.
    pub fn repo_path_expanded(&self) -> PathBuf {
        Self::expand_path(&self.repo_path)
    }

    /// Get agent home configuration by name.
    pub fn get_agent(&self, name: &str) -> Option<&AgentHome> {
        self.agents.get(name)
    }

    /// Get expanded agent home path.
    pub fn agent_home_path(&self, name: &str) -> Option<PathBuf> {
        self.agents.get(name).map(|a| Self::expand_path(&a.home))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = Config::default();
        assert!(config.agents.contains_key("claude"));
        assert!(config.agents.contains_key("openai"));
        assert!(config.agents.contains_key("cursor"));
        assert!(config.agents.contains_key("pi"));
        assert!(config.agents.contains_key("goose"));
    }

    #[test]
    fn test_expand_path() {
        let path = PathBuf::from("~/.claude");
        let expanded = Config::expand_path(&path);
        assert!(!expanded.to_string_lossy().starts_with("~"));
    }

    #[test]
    fn test_serialize_config() {
        let config = Config::default();
        let toml = toml::to_string_pretty(&config).unwrap();
        assert!(toml.contains("claude"));
    }
}
