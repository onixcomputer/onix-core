//! AgentKit: Universal AI agent instruction format and management tool.
//!
//! Manages skills, commands, and instructions across multiple AI agents
//! including Claude Code, OpenAI Codex, Cursor, and others.
//!
//! Successor to claude-md with multi-agent support.

mod config;
mod repo;
mod schema;

use clap::{Parser, Subcommand};
use colored::Colorize;
use config::Config;
use repo::{ItemStatus, LinkStatus, SyncStatus};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "agentkit")]
#[command(about = "Universal AI agent instruction format and management tool")]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Initialize the central repository
    Init {
        /// Path to initialize (default: ~/git/agentkit)
        #[arg(short, long)]
        path: Option<PathBuf>,
    },

    /// Add current project to central management
    ///
    /// Links instruction files (CLAUDE.local.md, AGENTS.md) and agent config
    /// directories (.claude/, .codex/) for the current git repository.
    Add,

    /// Add global skill(s) to central management
    AddSkill {
        /// Skill name(s) to add
        names: Vec<String>,

        /// Agent to add from (claude, openai, cursor)
        #[arg(short, long, default_value = "claude")]
        agent: String,

        /// Add all skills from the agent
        #[arg(long)]
        all: bool,
    },

    /// Add global command(s) to central management
    AddCommand {
        /// Command name(s) to add
        names: Vec<String>,

        /// Agent to add from
        #[arg(short, long, default_value = "claude")]
        agent: String,

        /// Add all commands from the agent
        #[arg(long)]
        all: bool,
    },

    /// List all skills and their status
    ListSkills {
        /// Show detailed information
        #[arg(short, long)]
        verbose: bool,
    },

    /// List all commands and their status
    ListCommands,

    /// Export skills to a specific agent format
    Export {
        /// Target agent (claude, openai, cursor)
        agent: String,

        /// Output directory (default: stdout)
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// Only export specific skills
        #[arg(short, long)]
        skill: Option<Vec<String>>,
    },

    /// Sync skills to agent homes via symlinks
    Sync {
        /// Specific agent to sync (default: all)
        #[arg(short, long)]
        agent: Option<String>,
    },

    /// Show status overview
    Status,

    /// Show or edit configuration
    Config {
        /// Show configuration path
        #[arg(long)]
        path: bool,

        /// Initialize default configuration
        #[arg(long)]
        init: bool,
    },

    /// Parse and validate a SKILL.md file
    Validate {
        /// Path to SKILL.md file
        file: PathBuf,
    },

    /// Convert a skill between formats
    Convert {
        /// Input SKILL.md file
        input: PathBuf,

        /// Target format (claude, openai, cursor, agents-md)
        #[arg(short, long, default_value = "agents-md")]
        format: String,

        /// Output file (default: stdout)
        #[arg(short, long)]
        output: Option<PathBuf>,
    },
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Init { path } => cmd_init(path),
        Commands::Add => cmd_add(),
        Commands::AddSkill { names, agent, all } => cmd_add_item("skills", names, agent, all),
        Commands::AddCommand { names, agent, all } => cmd_add_item("commands", names, agent, all),
        Commands::ListSkills { verbose } => cmd_list_items("skills", verbose),
        Commands::ListCommands => cmd_list_items("commands", false),
        Commands::Export {
            agent,
            output,
            skill,
        } => cmd_export(agent, output, skill),
        Commands::Sync { agent } => cmd_sync(agent),
        Commands::Status => cmd_status(),
        Commands::Config { path, init } => cmd_config(path, init),
        Commands::Validate { file } => cmd_validate(file),
        Commands::Convert {
            input,
            format,
            output,
        } => cmd_convert(input, format, output),
    }
}

fn cmd_init(path: Option<PathBuf>) -> anyhow::Result<()> {
    let mut config = Config::load()?;

    if let Some(p) = path {
        config.repo_path = p;
    }

    let repo = repo::Repo::open_or_init(&config)?;
    println!(
        "{} Initialized repository at {}",
        "OK".green().bold(),
        repo.path().display()
    );

    config.save()?;
    println!(
        "   Configuration saved to {}",
        Config::config_path().display()
    );

    if config.remote.is_some() {
        println!("   Remote: {}", config.remote.as_deref().unwrap());
    } else {
        println!(
            "   {}",
            "Tip: Set AGENTKIT_REMOTE or CLAUDE_MD_REMOTE to sync across machines".dimmed()
        );
    }

    Ok(())
}

fn cmd_add() -> anyhow::Result<()> {
    let config = Config::load()?;
    let repo = repo::Repo::open_or_init(&config)?;

    let result = repo.add_project()?;

    println!("Managing agent config for: {}", result.project_name.bold());

    for item in &result.items {
        let status_str = match &item.status {
            LinkStatus::AlreadyLinked => "already linked".dimmed().to_string(),
            LinkStatus::LinkedFromCentral => "linked (from central)".green().to_string(),
            LinkStatus::MovedAndLinked => "moved to central, symlinked back".green().to_string(),
            LinkStatus::Skipped => "skipped (not found)".dimmed().to_string(),
        };

        println!("  [{}] {}: {}", item.agent.cyan(), item.name, status_str);
    }

    Ok(())
}

fn cmd_add_item(kind: &str, names: Vec<String>, agent: String, all: bool) -> anyhow::Result<()> {
    let config = Config::load()?;
    let repo = repo::Repo::open_or_init(&config)?;

    let names_to_add = if all {
        let items = repo.list_agent_items(kind, &agent)?;
        if items.is_empty() {
            println!("No {kind} found for {agent}.");
            return Ok(());
        }
        println!("Managing all {kind} from {agent}:");
        items
    } else if names.is_empty() {
        anyhow::bail!("Specify name(s) or use --all");
    } else {
        names
    };

    for name in &names_to_add {
        match repo.add_item(kind, name, &agent) {
            Ok(status) => {
                let label = match status {
                    LinkStatus::AlreadyLinked => "already linked".dimmed().to_string(),
                    LinkStatus::LinkedFromCentral => "linked".green().to_string(),
                    LinkStatus::MovedAndLinked => "added".green().to_string(),
                    LinkStatus::Skipped => "not found".yellow().to_string(),
                };
                println!("  {name}: {label}");
            }
            Err(e) => println!("  {name}: {}", format!("{e}").red()),
        }
    }

    Ok(())
}

fn cmd_list_items(kind: &str, verbose: bool) -> anyhow::Result<()> {
    let config = Config::load()?;
    let repo = repo::Repo::open_or_init(&config)?;

    let items = repo.list_items(kind)?;

    if items.is_empty() {
        println!("No {kind} found.");
        return Ok(());
    }

    let singular = kind.strip_suffix('s').unwrap_or(kind);
    println!("{:<10} {}", "Status".bold(), singular.to_uppercase().bold());
    println!("{:<10} {}", "------", "----");

    for item in &items {
        let symbol = item.status.symbol();
        let agents_str = match &item.status {
            ItemStatus::Linked(agents) => format!(" ({})", agents.join(", ")).dimmed().to_string(),
            ItemStatus::Local(agents) => format!(" ({})", agents.join(", ")).dimmed().to_string(),
            ItemStatus::Conflict(agents) => format!(" ({})", agents.join(", ")).red().to_string(),
            _ => String::new(),
        };

        println!("  {symbol:<8} {}{agents_str}", item.name);

        if verbose {
            if let Some(ref meta) = item.meta {
                println!("           {}", meta.description.dimmed());
                if meta.is_legacy_format() {
                    println!("           {}", "(legacy Claude format)".yellow());
                }
                if !meta.capabilities.is_empty() {
                    println!("           capabilities: {:?}", meta.capabilities);
                }
            }
        }
    }

    println!();
    println!("  {}  linked (managed by agentkit)", "->".green());
    println!("      local only (run 'agentkit add-{singular} <name>' to manage)");
    println!(
        "  {}  central only (run 'agentkit sync' to restore)",
        "??".yellow()
    );
    println!("  {}  conflict (exists in both locations)", "!!".red());

    Ok(())
}

fn cmd_export(
    agent: String,
    output: Option<PathBuf>,
    skill_filter: Option<Vec<String>>,
) -> anyhow::Result<()> {
    let config = Config::load()?;
    let repo = repo::Repo::open_or_init(&config)?;

    let exported = repo.export_skills(&agent)?;

    if exported.is_empty() {
        println!("No skills to export.");
        return Ok(());
    }

    let exported: Vec<_> = if let Some(ref filter) = skill_filter {
        exported
            .into_iter()
            .filter(|s| filter.contains(&s.name))
            .collect()
    } else {
        exported
    };

    if let Some(ref output_dir) = output {
        std::fs::create_dir_all(output_dir)?;

        for skill in &exported {
            let skill_dir = output_dir.join(&skill.name);
            std::fs::create_dir_all(&skill_dir)?;

            let file_path = skill_dir.join(&skill.filename);
            std::fs::write(&file_path, &skill.content)?;

            println!("  {} {}", "OK".green(), file_path.display());
        }
    } else {
        for skill in &exported {
            println!(
                "{}",
                format!("# {} ({})", skill.name, skill.filename)
                    .cyan()
                    .bold()
            );
            println!("{}", skill.content);
            println!();
        }
    }

    Ok(())
}

fn cmd_sync(agent: Option<String>) -> anyhow::Result<()> {
    let config = Config::load()?;
    let repo = repo::Repo::open_or_init(&config)?;

    let agents: Vec<String> = if let Some(a) = agent {
        vec![a]
    } else {
        config.agents.keys().cloned().collect()
    };

    for agent_name in &agents {
        println!("{} Syncing to {}...", "->".blue(), agent_name);

        match repo.sync_agent(agent_name) {
            Ok(results) => {
                if results.is_empty() {
                    println!("  No skills to sync.");
                    continue;
                }
                for item in &results {
                    let label = match item.status {
                        SyncStatus::Symlinked => "symlinked".green().to_string(),
                        SyncStatus::Wrote => "wrote .mdc".green().to_string(),
                        SyncStatus::AlreadyLinked => "already linked".dimmed().to_string(),
                        SyncStatus::Skipped => "skipped (local exists)".yellow().to_string(),
                    };
                    println!("  {}: {label}", item.name);
                }
            }
            Err(e) => println!("  {}", format!("{e}").red()),
        }
    }

    Ok(())
}

fn cmd_status() -> anyhow::Result<()> {
    let config = Config::load()?;
    let repo = repo::Repo::open_or_init(&config)?;

    println!("{}", "AgentKit Status".bold());
    println!();
    println!("Central repo: {}", repo.path().display());
    println!("Config file:  {}", Config::config_path().display());
    if let Some(ref remote) = config.remote {
        println!("Remote:       {remote}");
    }
    println!();

    // Projects
    let projects = repo.list_projects()?;
    if !projects.is_empty() {
        println!("{}:", "Projects".bold());
        for project in &projects {
            println!("  {project}");
        }
        println!();
    }

    // Skills
    let skills = repo.list_items("skills")?;
    if !skills.is_empty() {
        println!("{}:", "Global Skills".bold());
        for item in &skills {
            let status_str = match &item.status {
                ItemStatus::Linked(agents) => {
                    format!("{} {}", "->".green(), agents.join(", ").dimmed())
                }
                ItemStatus::Local(agents) => {
                    format!("local:{}", agents.join(", "))
                }
                ItemStatus::Central => "central".yellow().to_string(),
                ItemStatus::Conflict(agents) => {
                    format!("{} {}", "!!".red(), agents.join(", "))
                }
                ItemStatus::Missing => "missing".dimmed().to_string(),
            };
            println!("  {:<20} {status_str}", item.name);
        }
        println!();
    }

    // Commands
    let commands = repo.list_items("commands")?;
    if !commands.is_empty() {
        println!("{}:", "Global Commands".bold());
        for item in &commands {
            let status_str = match &item.status {
                ItemStatus::Linked(agents) => {
                    format!("{} {}", "->".green(), agents.join(", ").dimmed())
                }
                ItemStatus::Local(agents) => {
                    format!("local:{}", agents.join(", "))
                }
                ItemStatus::Central => "central".yellow().to_string(),
                ItemStatus::Conflict(agents) => {
                    format!("{} {}", "!!".red(), agents.join(", "))
                }
                ItemStatus::Missing => "missing".dimmed().to_string(),
            };
            println!("  {:<20} {status_str}", item.name);
        }
        println!();
    }

    // Agents
    println!("{}:", "Configured Agents".bold());
    for (name, agent_cfg) in &config.agents {
        let home = Config::expand_path(&agent_cfg.home);
        let exists = home.exists();
        let status = if exists {
            "OK".green()
        } else {
            "missing".yellow()
        };
        println!("  {name:<10} {} ({})", home.display(), status);
    }

    Ok(())
}

fn cmd_config(show_path: bool, init: bool) -> anyhow::Result<()> {
    if show_path {
        println!("{}", Config::config_path().display());
        return Ok(());
    }

    if init {
        let config = Config::default();
        config.save()?;
        println!(
            "{} Created configuration at {}",
            "OK".green(),
            Config::config_path().display()
        );
        return Ok(());
    }

    let config = Config::load()?;
    let toml_str = toml::to_string_pretty(&config)?;
    println!("{toml_str}");

    Ok(())
}

fn cmd_validate(file: PathBuf) -> anyhow::Result<()> {
    let content = std::fs::read_to_string(&file)?;

    match schema::Skill::parse(&content) {
        Ok(skill) => {
            println!("{} Valid SKILL.md", "OK".green().bold());
            println!();
            println!("Name:        {}", skill.meta.name);
            println!("Description: {}", skill.meta.description);

            if let Some(ref version) = skill.meta.version {
                println!("Version:     {version}");
            }

            if !skill.meta.capabilities.is_empty() {
                println!("Capabilities: {:?}", skill.meta.capabilities);
            }

            if skill.meta.is_legacy_format() {
                println!();
                println!(
                    "{}",
                    "Note: Uses legacy Claude-only format. Consider migrating to universal format."
                        .yellow()
                );
            }

            let has_agent_config = skill.meta.agents.claude.is_some()
                || skill.meta.agents.openai.is_some()
                || skill.meta.agents.cursor.is_some();

            if has_agent_config {
                println!();
                println!("Agent-specific configs:");
                if skill.meta.agents.claude.is_some() {
                    println!("  - claude");
                }
                if skill.meta.agents.openai.is_some() {
                    println!("  - openai");
                }
                if skill.meta.agents.cursor.is_some() {
                    println!("  - cursor");
                }
            }

            Ok(())
        }
        Err(e) => {
            println!("{} Invalid SKILL.md: {e}", "ERR".red().bold());
            std::process::exit(1);
        }
    }
}

fn cmd_convert(input: PathBuf, format: String, output: Option<PathBuf>) -> anyhow::Result<()> {
    let content = std::fs::read_to_string(&input)?;
    let skill = schema::Skill::parse(&content)?;

    let converted = match format.as_str() {
        "claude" => skill.to_claude_format(),
        "cursor" => skill.to_cursor_format(),
        "agents-md" | "openai" | "generic" => skill.to_agents_md_format(),
        _ => anyhow::bail!("Unknown format: {format}. Use: claude, cursor, openai, agents-md"),
    };

    if let Some(ref output_path) = output {
        std::fs::write(output_path, &converted)?;
        println!(
            "{} Converted to {} format: {}",
            "OK".green(),
            format,
            output_path.display()
        );
    } else {
        println!("{converted}");
    }

    Ok(())
}
