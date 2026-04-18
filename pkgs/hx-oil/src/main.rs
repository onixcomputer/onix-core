use std::path::PathBuf;

use anyhow::Result;
use clap::{Parser, Subcommand};

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
    Gc,
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
        Command::Gc => {
            println!("{}", hx_oil::ensure_gc(&state_home)?);
        }
    }

    Ok(())
}
