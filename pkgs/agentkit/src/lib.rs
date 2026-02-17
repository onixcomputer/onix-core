//! AgentKit: Universal AI agent instruction format library.
//!
//! This library provides types and utilities for working with the universal
//! SKILL.md format that works across multiple AI agents.
//!
//! # Supported Agents
//!
//! - **Claude Code** (Anthropic) - CLAUDE.md, SKILL.md with YAML frontmatter
//! - **OpenAI Codex** - AGENTS.md, SKILL.md
//! - **Cursor** - .mdc files in .cursor/rules/
//! - **Generic** - AGENTS.md (Linux Foundation standard)
//!
//! # Example
//!
//! ```rust
//! use agentkit::schema::Skill;
//!
//! let skill_md = r#"---
//! name: my-skill
//! description: A useful skill
//! capabilities:
//!   - read_files
//!   - write_files
//! ---
//!
//! # My Skill
//!
//! Instructions for the agent...
//! "#;
//!
//! let skill = Skill::parse(skill_md).unwrap();
//! assert_eq!(skill.meta.name, "my-skill");
//!
//! // Export to different formats
//! let claude_format = skill.to_claude_format();
//! let cursor_format = skill.to_cursor_format();
//! let agents_md = skill.to_agents_md_format();
//! ```

pub mod config;
pub mod repo;
pub mod schema;

pub use config::Config;
pub use repo::Repo;
pub use schema::{Capability, Skill, SkillMeta};
