//! Repository management for the central agent.md repository.

use crate::config::Config;
use crate::schema::{Skill, SkillParseError};
use std::path::{Path, PathBuf};
use thiserror::Error;
use walkdir::WalkDir;

/// Directory for global configuration.
const GLOBAL_DIR: &str = "_global";

/// Error types for repository operations.
#[derive(Debug, Error)]
pub enum RepoError {
    #[error("Not in a git repository")]
    NotInGitRepo,

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Git error: {0}")]
    Git(String),

    #[error("Skill parse error: {0}")]
    SkillParse(#[from] SkillParseError),

    #[error("Conflict: {0} exists in both locations")]
    Conflict(String),
}

/// Repository manager for agent.md.
pub struct Repo {
    /// Path to the central repository.
    path: PathBuf,

    /// Configuration.
    config: Config,
}

impl Repo {
    /// Open or initialize the repository.
    pub fn open_or_init(config: &Config) -> Result<Self, RepoError> {
        let path = config.repo_path_expanded();

        if !path.exists() {
            Self::init_repo(&path, config)?;
        }

        Ok(Self {
            path,
            config: config.clone(),
        })
    }

    /// Initialize a new repository, optionally cloning from remote.
    fn init_repo(path: &Path, config: &Config) -> Result<(), RepoError> {
        if let Some(ref remote) = config.remote {
            // Clone from remote
            let parent = path.parent().unwrap();
            std::fs::create_dir_all(parent)?;

            let output = std::process::Command::new("git")
                .args(["clone", remote, &path.to_string_lossy()])
                .output()?;

            if !output.status.success() {
                return Err(RepoError::Git(
                    String::from_utf8_lossy(&output.stderr).to_string(),
                ));
            }
        } else {
            std::fs::create_dir_all(path)?;

            let output = std::process::Command::new("git")
                .args(["init"])
                .current_dir(path)
                .output()?;

            if !output.status.success() {
                return Err(RepoError::Git(
                    String::from_utf8_lossy(&output.stderr).to_string(),
                ));
            }
        }

        // Create global directories
        std::fs::create_dir_all(path.join(GLOBAL_DIR).join("skills"))?;
        std::fs::create_dir_all(path.join(GLOBAL_DIR).join("commands"))?;

        Ok(())
    }

    /// Get the repository path.
    pub fn path(&self) -> &Path {
        &self.path
    }

    /// Get the global directory for a kind (skills, commands).
    pub fn global_dir(&self, kind: &str) -> PathBuf {
        self.path.join(GLOBAL_DIR).join(kind)
    }

    /// Get project directory in the central repo.
    pub fn project_dir(&self, project_name: &str) -> PathBuf {
        self.path.join(project_name)
    }

    // ---- Per-project management ----

    /// Detect the current git repository root.
    pub fn detect_git_root() -> Result<PathBuf, RepoError> {
        let output = std::process::Command::new("git")
            .args(["rev-parse", "--show-toplevel"])
            .output()?;

        if !output.status.success() {
            return Err(RepoError::NotInGitRepo);
        }

        Ok(PathBuf::from(
            String::from_utf8_lossy(&output.stdout).trim(),
        ))
    }

    /// Add a project to central management.
    ///
    /// For each configured agent, manages:
    /// - The agent's config directory (e.g. .claude/, .codex/)
    /// - The agent's instruction file (e.g. CLAUDE.local.md, AGENTS.md)
    pub fn add_project(&self) -> Result<ProjectAddResult, RepoError> {
        let repo_root = Self::detect_git_root()?;
        let project_name = repo_root
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();

        let central_project_dir = self.project_dir(&project_name);
        std::fs::create_dir_all(&central_project_dir)?;

        let mut result = ProjectAddResult {
            project_name: project_name.clone(),
            items: Vec::new(),
        };

        // For each agent, handle its config directory and instruction files
        for (agent_name, agent_config) in &self.config.agents {
            // Handle agent config directory (e.g. .claude/, .codex/)
            // Cursor uses .cursor/rules/ which is project-relative, not home-relative
            if !agent_config.uses_mdc {
                // Extract the config dir name from the agent home path.
                // ~/.claude -> .claude, ~/.codex -> .codex
                let home_basename = agent_config
                    .home
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or(agent_name);

                // If it already starts with '.', use as-is; otherwise prefix '.'
                let config_dir_name = if home_basename.starts_with('.') {
                    home_basename.to_string()
                } else {
                    format!(".{home_basename}")
                };

                let local_config_dir = repo_root.join(&config_dir_name);
                let central_config_dir = central_project_dir.join(&config_dir_name);

                let status = self.link_directory(&local_config_dir, &central_config_dir)?;
                result.items.push(LinkItem {
                    agent: agent_name.clone(),
                    name: config_dir_name,
                    status,
                });
            }

            // Handle instruction file (e.g. CLAUDE.local.md, AGENTS.md)
            if let Some(ref instruction_file) = agent_config.instruction_file {
                // For Claude, use CLAUDE.local.md (the .local variant)
                let local_filename = if instruction_file == "CLAUDE.md" {
                    "CLAUDE.local.md".to_string()
                } else {
                    instruction_file.clone()
                };

                let local_file = repo_root.join(&local_filename);
                let central_file = central_project_dir.join(&local_filename);

                let status = self.link_file(&local_file, &central_file)?;
                result.items.push(LinkItem {
                    agent: agent_name.clone(),
                    name: local_filename,
                    status,
                });
            }
        }

        Ok(result)
    }

    /// Link a directory between a local path and central repo.
    fn link_directory(
        &self,
        local_dir: &Path,
        central_dir: &Path,
    ) -> Result<LinkStatus, RepoError> {
        // Both exist
        if local_dir.exists() && central_dir.exists() {
            if local_dir.is_symlink() {
                if let Ok(target) = std::fs::canonicalize(local_dir) {
                    if let Ok(central_canonical) = std::fs::canonicalize(central_dir) {
                        if target == central_canonical {
                            return Ok(LinkStatus::AlreadyLinked);
                        }
                    }
                }
            }
            return Err(RepoError::Conflict(local_dir.to_string_lossy().to_string()));
        }

        // Central exists, local doesn't -> create symlink
        if central_dir.exists() && !local_dir.exists() {
            std::os::unix::fs::symlink(central_dir, local_dir)?;
            return Ok(LinkStatus::LinkedFromCentral);
        }

        // Local exists, central doesn't -> move to central, symlink back
        if local_dir.exists() && !central_dir.exists() {
            std::fs::create_dir_all(central_dir.parent().unwrap())?;
            copy_dir_recursive(local_dir, central_dir)?;
            std::fs::remove_dir_all(local_dir)?;
            std::os::unix::fs::symlink(central_dir, local_dir)?;
            self.git_add(central_dir)?;
            return Ok(LinkStatus::MovedAndLinked);
        }

        // Neither exists
        Ok(LinkStatus::Skipped)
    }

    /// Link a file between a local path and central repo.
    fn link_file(&self, local_file: &Path, central_file: &Path) -> Result<LinkStatus, RepoError> {
        // Both exist
        if local_file.exists() && central_file.exists() {
            if local_file.is_symlink() {
                if let Ok(target) = std::fs::canonicalize(local_file) {
                    if let Ok(central_canonical) = std::fs::canonicalize(central_file) {
                        if target == central_canonical {
                            return Ok(LinkStatus::AlreadyLinked);
                        }
                    }
                }
            }
            return Err(RepoError::Conflict(
                local_file.to_string_lossy().to_string(),
            ));
        }

        // Central exists, local doesn't -> symlink
        if central_file.exists() && !local_file.exists() {
            std::os::unix::fs::symlink(central_file, local_file)?;
            return Ok(LinkStatus::LinkedFromCentral);
        }

        // Local exists, central doesn't -> copy to central, symlink back
        if local_file.exists() && !central_file.exists() {
            std::fs::create_dir_all(central_file.parent().unwrap())?;
            std::fs::copy(local_file, central_file)?;
            std::fs::remove_file(local_file)?;
            std::os::unix::fs::symlink(central_file, local_file)?;
            self.git_add(central_file)?;
            return Ok(LinkStatus::MovedAndLinked);
        }

        // Neither exists
        Ok(LinkStatus::Skipped)
    }

    // ---- Global items management (skills + commands) ----

    /// List all global items of a given kind.
    pub fn list_items(&self, kind: &str) -> Result<Vec<ItemInfo>, RepoError> {
        let items_dir = self.global_dir(kind);
        let mut items = Vec::new();

        if !items_dir.exists() {
            return Ok(items);
        }

        // Collect names from both central repo and all agent homes
        let mut names = std::collections::BTreeSet::new();

        for entry in std::fs::read_dir(&items_dir)? {
            let entry = entry?;
            if entry.path().is_dir() {
                let name = entry.file_name().to_string_lossy().to_string();
                if !name.starts_with('.') {
                    names.insert(name);
                }
            }
        }

        // Also check each agent's local directory
        for (_, agent_config) in &self.config.agents {
            let agent_home = Config::expand_path(&agent_config.home);
            let local_dir = match kind {
                "skills" => agent_home.join(&agent_config.skill_dir),
                "commands" => agent_home.join(&agent_config.command_dir),
                _ => continue,
            };
            if local_dir.exists() {
                if let Ok(entries) = std::fs::read_dir(&local_dir) {
                    for entry in entries.flatten() {
                        if entry.path().is_dir() {
                            let name = entry.file_name().to_string_lossy().to_string();
                            if !name.starts_with('.') {
                                names.insert(name);
                            }
                        }
                    }
                }
            }
        }

        for name in names {
            let status = self.get_item_status(kind, &name)?;

            let meta = if kind == "skills" {
                let skill_file = items_dir.join(&name).join("SKILL.md");
                if skill_file.exists() {
                    let content = std::fs::read_to_string(&skill_file)?;
                    Skill::parse(&content).ok().map(|s| s.meta)
                } else {
                    None
                }
            } else {
                None
            };

            items.push(ItemInfo { name, status, meta });
        }

        Ok(items)
    }

    /// Get the status of a global item across all agents.
    fn get_item_status(&self, kind: &str, name: &str) -> Result<ItemStatus, RepoError> {
        let central_dir = self.global_dir(kind).join(name);
        let central_exists = central_dir.exists();

        let mut linked_agents = Vec::new();
        let mut local_agents = Vec::new();
        let mut conflict_agents = Vec::new();

        for (agent_name, agent_config) in &self.config.agents {
            let agent_home = Config::expand_path(&agent_config.home);
            let local_dir = match kind {
                "skills" => agent_home.join(&agent_config.skill_dir).join(name),
                "commands" => agent_home.join(&agent_config.command_dir).join(name),
                _ => continue,
            };

            if local_dir.exists() || local_dir.is_symlink() {
                if local_dir.is_symlink() {
                    if let Ok(target) = std::fs::read_link(&local_dir) {
                        let resolved = if target.is_relative() {
                            local_dir.parent().unwrap().join(&target)
                        } else {
                            target
                        };

                        if resolved.starts_with(&central_dir) || resolved == central_dir {
                            linked_agents.push(agent_name.clone());
                            continue;
                        }
                    }
                }

                if central_exists {
                    conflict_agents.push(agent_name.clone());
                } else {
                    local_agents.push(agent_name.clone());
                }
            }
        }

        if !conflict_agents.is_empty() {
            Ok(ItemStatus::Conflict(conflict_agents))
        } else if !linked_agents.is_empty() {
            Ok(ItemStatus::Linked(linked_agents))
        } else if !local_agents.is_empty() {
            Ok(ItemStatus::Local(local_agents))
        } else if central_exists {
            Ok(ItemStatus::Central)
        } else {
            Ok(ItemStatus::Missing)
        }
    }

    /// List all items in an agent's local directory.
    pub fn list_agent_items(&self, kind: &str, agent: &str) -> Result<Vec<String>, RepoError> {
        let agent_config = self
            .config
            .get_agent(agent)
            .ok_or_else(|| RepoError::Git(format!("Unknown agent: {agent}")))?;

        let agent_home = Config::expand_path(&agent_config.home);
        let local_dir = match kind {
            "skills" => agent_home.join(&agent_config.skill_dir),
            "commands" => agent_home.join(&agent_config.command_dir),
            _ => return Ok(Vec::new()),
        };

        if !local_dir.exists() {
            return Ok(Vec::new());
        }

        let mut names = Vec::new();
        for entry in std::fs::read_dir(&local_dir)? {
            let entry = entry?;
            if entry.path().is_dir() {
                let name = entry.file_name().to_string_lossy().to_string();
                if !name.starts_with('.') {
                    names.push(name);
                }
            }
        }

        names.sort();
        Ok(names)
    }

    /// Add a global item to central management.
    pub fn add_item(&self, kind: &str, name: &str, agent: &str) -> Result<LinkStatus, RepoError> {
        let agent_config = self
            .config
            .get_agent(agent)
            .ok_or_else(|| RepoError::Git(format!("Unknown agent: {agent}")))?;

        let agent_home = Config::expand_path(&agent_config.home);
        let local_dir = match kind {
            "skills" => agent_home.join(&agent_config.skill_dir).join(name),
            "commands" => agent_home.join(&agent_config.command_dir).join(name),
            _ => return Err(RepoError::Git(format!("Unknown kind: {kind}"))),
        };
        let central_dir = self.global_dir(kind).join(name);

        self.link_directory(&local_dir, &central_dir)
    }

    /// Export skills to a specific agent format.
    pub fn export_skills(&self, agent: &str) -> Result<Vec<ExportedSkill>, RepoError> {
        let agent_config = self
            .config
            .get_agent(agent)
            .ok_or_else(|| RepoError::Git(format!("Unknown agent: {agent}")))?;

        let mut exported = Vec::new();
        let skills_dir = self.global_dir("skills");

        if !skills_dir.exists() {
            return Ok(exported);
        }

        for entry in std::fs::read_dir(&skills_dir)? {
            let entry = entry?;
            let path = entry.path();

            if !path.is_dir() {
                continue;
            }

            let skill_file = path.join("SKILL.md");
            if !skill_file.exists() {
                continue;
            }

            let content = std::fs::read_to_string(&skill_file)?;
            let skill = Skill::parse(&content)?;

            // Check if disabled for this agent
            let disabled = match agent {
                "claude" => skill
                    .meta
                    .agents
                    .claude
                    .as_ref()
                    .is_some_and(|c| c.disabled),
                "openai" => skill
                    .meta
                    .agents
                    .openai
                    .as_ref()
                    .is_some_and(|c| c.disabled),
                "cursor" => skill
                    .meta
                    .agents
                    .cursor
                    .as_ref()
                    .is_some_and(|c| c.disabled),
                "pi" => skill.meta.agents.pi.as_ref().is_some_and(|c| c.disabled),
                "goose" => skill.meta.agents.goose.as_ref().is_some_and(|c| c.disabled),
                _ => false,
            };

            if disabled {
                continue;
            }

            let output_content = match agent {
                "claude" => skill.to_claude_format(),
                "cursor" => skill.to_cursor_format(),
                _ => skill.to_agents_md_format(),
            };

            let output_filename = if agent_config.uses_mdc {
                format!("{}.mdc", skill.meta.name)
            } else {
                "SKILL.md".to_string()
            };

            exported.push(ExportedSkill {
                name: skill.meta.name.clone(),
                content: output_content,
                filename: output_filename,
            });
        }

        Ok(exported)
    }

    /// Sync all global skills to an agent's home directory.
    pub fn sync_agent(&self, agent: &str) -> Result<Vec<SyncItem>, RepoError> {
        let agent_config = self
            .config
            .get_agent(agent)
            .ok_or_else(|| RepoError::Git(format!("Unknown agent: {agent}")))?;

        let agent_home = Config::expand_path(&agent_config.home);
        let skill_dir = agent_home.join(&agent_config.skill_dir);
        let mut results = Vec::new();

        let exported = self.export_skills(agent)?;

        if exported.is_empty() {
            return Ok(results);
        }

        std::fs::create_dir_all(&skill_dir)?;

        for skill in &exported {
            let central_skill_dir = self.global_dir("skills").join(&skill.name);
            let target_skill_dir = skill_dir.join(&skill.name);

            if !target_skill_dir.exists() && !target_skill_dir.is_symlink() {
                if agent_config.uses_mdc {
                    // Cursor: write converted .mdc directly
                    let mdc_file = skill_dir.join(&skill.filename);
                    std::fs::write(&mdc_file, &skill.content)?;
                    results.push(SyncItem {
                        name: skill.name.clone(),
                        status: SyncStatus::Wrote,
                    });
                } else {
                    // Symlink directory
                    std::os::unix::fs::symlink(&central_skill_dir, &target_skill_dir)?;
                    results.push(SyncItem {
                        name: skill.name.clone(),
                        status: SyncStatus::Symlinked,
                    });
                }
            } else if target_skill_dir.is_symlink() {
                results.push(SyncItem {
                    name: skill.name.clone(),
                    status: SyncStatus::AlreadyLinked,
                });
            } else {
                results.push(SyncItem {
                    name: skill.name.clone(),
                    status: SyncStatus::Skipped,
                });
            }
        }

        Ok(results)
    }

    /// Stage a path in git.
    fn git_add(&self, path: &Path) -> Result<(), RepoError> {
        let relative = path.strip_prefix(&self.path).unwrap_or(path);

        let output = std::process::Command::new("git")
            .args(["add", "-f", &relative.to_string_lossy()])
            .current_dir(&self.path)
            .output()?;

        if !output.status.success() {
            return Err(RepoError::Git(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ));
        }

        Ok(())
    }

    /// List all managed projects.
    pub fn list_projects(&self) -> Result<Vec<String>, RepoError> {
        let mut projects = Vec::new();

        for entry in std::fs::read_dir(&self.path)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let name = path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or_default();

                if !name.starts_with('.') && name != GLOBAL_DIR {
                    projects.push(name.to_string());
                }
            }
        }

        projects.sort();
        Ok(projects)
    }
}

/// Status of a link operation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LinkStatus {
    AlreadyLinked,
    LinkedFromCentral,
    MovedAndLinked,
    Skipped,
}

impl std::fmt::Display for LinkStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::AlreadyLinked => write!(f, "already linked"),
            Self::LinkedFromCentral => write!(f, "linked (from central)"),
            Self::MovedAndLinked => write!(f, "moved to central, symlinked back"),
            Self::Skipped => write!(f, "skipped (not found)"),
        }
    }
}

/// Result of adding a project.
#[derive(Debug)]
pub struct ProjectAddResult {
    pub project_name: String,
    pub items: Vec<LinkItem>,
}

/// A single linked item from add_project.
#[derive(Debug)]
pub struct LinkItem {
    pub agent: String,
    pub name: String,
    pub status: LinkStatus,
}

/// Status of a global item across agents.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ItemStatus {
    Linked(Vec<String>),
    Local(Vec<String>),
    Central,
    Conflict(Vec<String>),
    Missing,
}

impl ItemStatus {
    /// Get a short symbol for display.
    pub fn symbol(&self) -> &'static str {
        match self {
            Self::Linked(_) => "->",
            Self::Local(_) => "  ",
            Self::Central => "??",
            Self::Conflict(_) => "!!",
            Self::Missing => "  ",
        }
    }
}

/// Information about a global item.
#[derive(Debug, Clone)]
pub struct ItemInfo {
    pub name: String,
    pub status: ItemStatus,
    pub meta: Option<crate::schema::SkillMeta>,
}

/// Result of syncing a skill to an agent.
#[derive(Debug)]
pub struct SyncItem {
    pub name: String,
    pub status: SyncStatus,
}

#[derive(Debug)]
pub enum SyncStatus {
    Symlinked,
    Wrote,
    AlreadyLinked,
    Skipped,
}

/// Exported skill for an agent.
#[derive(Debug, Clone)]
pub struct ExportedSkill {
    pub name: String,
    pub content: String,
    pub filename: String,
}

/// Recursively copy a directory.
fn copy_dir_recursive(src: &Path, dst: &Path) -> Result<(), std::io::Error> {
    std::fs::create_dir_all(dst)?;

    for entry in WalkDir::new(src).min_depth(1).max_depth(1) {
        let entry = entry?;
        let src_path = entry.path();
        let dst_path = dst.join(src_path.file_name().unwrap());

        if src_path.is_dir() {
            copy_dir_recursive(src_path, &dst_path)?;
        } else if src_path.is_symlink() {
            let target = std::fs::read_link(src_path)?;
            std::os::unix::fs::symlink(target, &dst_path)?;
        } else {
            std::fs::copy(src_path, &dst_path)?;
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_item_status_symbol() {
        assert_eq!(ItemStatus::Linked(vec!["claude".into()]).symbol(), "->");
        assert_eq!(ItemStatus::Central.symbol(), "??");
        assert_eq!(ItemStatus::Conflict(vec!["openai".into()]).symbol(), "!!");
    }

    #[test]
    fn test_link_status_display() {
        assert_eq!(LinkStatus::AlreadyLinked.to_string(), "already linked");
        assert_eq!(
            LinkStatus::MovedAndLinked.to_string(),
            "moved to central, symlinked back"
        );
    }
}
