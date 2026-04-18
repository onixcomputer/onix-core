use std::path::PathBuf;

use anyhow::Result;
use clap::{Parser, Subcommand, ValueEnum};

#[derive(Debug, Parser)]
#[command(author, version, about = "Editable Helix directory manifests")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Render {
        #[arg(long)]
        from: PathBuf,
    },
    Refresh {
        manifest: PathBuf,
    },
    Apply {
        #[arg(long)]
        dry_run: bool,
        manifest: PathBuf,
    },
    OpenAtLine {
        manifest: PathBuf,
        line: usize,
    },
    Parent {
        manifest: PathBuf,
    },
    MarkToggle {
        manifest: PathBuf,
        lines: Vec<usize>,
    },
    ClearMarks {
        manifest: PathBuf,
    },
    RememberAlternate {
        manifest: PathBuf,
    },
    FlagDelete {
        manifest: PathBuf,
        lines: Vec<usize>,
    },
    Op {
        kind: BulkKindArg,
        manifest: PathBuf,
        #[arg(long)]
        execute: bool,
        #[arg(long)]
        target: Option<PathBuf>,
        #[arg(long)]
        target_manifest: Option<PathBuf>,
        #[arg(long)]
        alternate_manifest: Option<PathBuf>,
    },
    Transform {
        #[command(subcommand)]
        kind: TransformCommand,
    },
    Subdir {
        #[command(subcommand)]
        command: SubdirCommand,
    },
    Gc,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
enum BulkKindArg {
    Copy,
    Move,
    Symlink,
    RelativeSymlink,
}

impl From<BulkKindArg> for hx_oil::BulkKind {
    fn from(value: BulkKindArg) -> Self {
        match value {
            BulkKindArg::Copy => Self::Copy,
            BulkKindArg::Move => Self::Move,
            BulkKindArg::Symlink => Self::Symlink,
            BulkKindArg::RelativeSymlink => Self::RelativeSymlink,
        }
    }
}

#[derive(Debug, Subcommand)]
enum TransformCommand {
    Regex {
        manifest: PathBuf,
        #[arg(long)]
        pattern: String,
        #[arg(long)]
        replace: String,
        #[arg(long)]
        execute: bool,
    },
    Prefix {
        manifest: PathBuf,
        #[arg(long)]
        value: String,
        #[arg(long)]
        execute: bool,
    },
    Suffix {
        manifest: PathBuf,
        #[arg(long)]
        value: String,
        #[arg(long)]
        execute: bool,
    },
    Lower {
        manifest: PathBuf,
        #[arg(long)]
        execute: bool,
    },
    Upper {
        manifest: PathBuf,
        #[arg(long)]
        execute: bool,
    },
}

#[derive(Debug, Subcommand)]
enum SubdirCommand {
    Insert { manifest: PathBuf, line: usize },
    Collapse { manifest: PathBuf, line: usize },
    Refresh { manifest: PathBuf, line: usize },
}

fn main() {
    if let Err(error) = run() {
        eprintln!("error: {error:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();
    let state_home = hx_oil::xdg_state_home()?;

    match cli.command {
        Command::Render { from } => {
            hx_oil::ensure_gc(&state_home)?;
            println!("{}", hx_oil::render_session(&from, &state_home)?.display());
        }
        Command::Refresh { manifest } => {
            hx_oil::ensure_gc(&state_home)?;
            println!("{}", hx_oil::refresh_session(&manifest)?.display());
        }
        Command::Apply { dry_run, manifest } => {
            hx_oil::ensure_gc(&state_home)?;
            let output = if dry_run {
                hx_oil::dry_run_apply(&manifest)?
            } else {
                hx_oil::apply_manifest(&manifest)?
            };
            print!("{output}");
        }
        Command::OpenAtLine { manifest, line } => {
            hx_oil::ensure_gc(&state_home)?;
            println!(
                "{}",
                hx_oil::open_at_line(&manifest, line, &state_home)?.display()
            );
        }
        Command::Parent { manifest } => {
            hx_oil::ensure_gc(&state_home)?;
            println!(
                "{}",
                hx_oil::parent_session(&manifest, &state_home)?.display()
            );
        }
        Command::MarkToggle { manifest, lines } => {
            hx_oil::ensure_gc(&state_home)?;
            println!("{}", hx_oil::mark_toggle(&manifest, &lines)?.display());
        }
        Command::ClearMarks { manifest } => {
            hx_oil::ensure_gc(&state_home)?;
            println!("{}", hx_oil::clear_marks(&manifest)?.display());
        }
        Command::RememberAlternate { manifest } => {
            hx_oil::ensure_gc(&state_home)?;
            println!(
                "{}",
                hx_oil::remember_alternate_manifest(&manifest, &state_home)?.display()
            );
        }
        Command::FlagDelete { manifest, lines } => {
            hx_oil::ensure_gc(&state_home)?;
            println!("{}", hx_oil::flag_delete(&manifest, &lines)?.display());
        }
        Command::Op {
            kind,
            manifest,
            execute,
            target,
            target_manifest,
            alternate_manifest,
        } => {
            hx_oil::ensure_gc(&state_home)?;
            print!(
                "{}",
                hx_oil::run_bulk_op(
                    &manifest,
                    kind.into(),
                    execute,
                    target.as_deref(),
                    target_manifest.as_deref(),
                    alternate_manifest.as_deref(),
                )?
            );
        }
        Command::Transform { kind } => {
            hx_oil::ensure_gc(&state_home)?;
            let output = match kind {
                TransformCommand::Regex {
                    manifest,
                    pattern,
                    replace,
                    execute,
                } => hx_oil::run_transform(
                    &manifest,
                    hx_oil::TransformKind::Regex { pattern, replace },
                    execute,
                )?,
                TransformCommand::Prefix {
                    manifest,
                    value,
                    execute,
                } => hx_oil::run_transform(
                    &manifest,
                    hx_oil::TransformKind::Prefix { value },
                    execute,
                )?,
                TransformCommand::Suffix {
                    manifest,
                    value,
                    execute,
                } => hx_oil::run_transform(
                    &manifest,
                    hx_oil::TransformKind::Suffix { value },
                    execute,
                )?,
                TransformCommand::Lower { manifest, execute } => {
                    hx_oil::run_transform(&manifest, hx_oil::TransformKind::Lower, execute)?
                }
                TransformCommand::Upper { manifest, execute } => {
                    hx_oil::run_transform(&manifest, hx_oil::TransformKind::Upper, execute)?
                }
            };
            print!("{output}");
        }
        Command::Subdir { command } => {
            hx_oil::ensure_gc(&state_home)?;
            let output = match command {
                SubdirCommand::Insert { manifest, line } => hx_oil::insert_subdir(&manifest, line)?,
                SubdirCommand::Collapse { manifest, line } => {
                    hx_oil::collapse_subdir(&manifest, line)?
                }
                SubdirCommand::Refresh { manifest, line } => {
                    hx_oil::refresh_subdir(&manifest, line)?
                }
            };
            println!("{}", output.display());
        }
        Command::Gc => {
            println!("{}", hx_oil::ensure_gc(&state_home)?);
        }
    }

    Ok(())
}
