#!/usr/bin/env python3
"""Manage Claude Code configuration across repositories.

Centralizes all Claude Code configuration into a single git repository
(~/git/claude.md) using symlinks, keeping it version-controlled without
committing to project repos.

Manages:
  - Per-project: CLAUDE.local.md files and .claude/ directories
  - Global: ~/.claude/skills/ and ~/.claude/commands/

Set CLAUDE_MD_REMOTE to configure the git remote for the central repo.
If unset, a local-only git repo is initialized.
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

GLOBAL_DIR = "_global"
CLAUDE_HOME = Path.home() / ".claude"


def get_repo_root() -> Path:
    """Get the root of the current git repository."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        return Path(result.stdout.strip())
    except subprocess.CalledProcessError:
        print("Error: Not in a git repository", file=sys.stderr)
        sys.exit(1)


def get_claude_md_repo() -> Path:
    """Get the claude.md repository path, cloning or initializing if needed."""
    claude_md_path = Path.home() / "git" / "claude.md"
    if not claude_md_path.exists():
        parent_dir = claude_md_path.parent
        parent_dir.mkdir(parents=True, exist_ok=True)

        remote = os.environ.get("CLAUDE_MD_REMOTE")
        if remote:
            print(f"Cloning claude.md repository to {claude_md_path}")
            try:
                subprocess.run(
                    ["git", "clone", remote, str(claude_md_path)],
                    check=True,
                    capture_output=True,
                )
                print(f"Cloned repository to {claude_md_path}")
            except subprocess.CalledProcessError as e:
                print(f"Error: Failed to clone repository: {e}", file=sys.stderr)
                sys.exit(1)
        else:
            print(f"Initializing claude.md repository at {claude_md_path}")
            claude_md_path.mkdir(parents=True, exist_ok=True)
            subprocess.run(
                ["git", "init"],
                cwd=claude_md_path,
                check=True,
                capture_output=True,
            )
            print(f"Initialized local repository at {claude_md_path}")
            print("Tip: Set CLAUDE_MD_REMOTE to sync with a remote git repo")
    return claude_md_path


def show_diff(file1: Path, file2: Path) -> None:
    """Show diff between two files."""
    try:
        result = subprocess.run(
            ["diff", "-u", str(file1), str(file2)],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.stdout:
            print(f"Diff between {file1} and {file2}:")
            print(result.stdout)
    except subprocess.CalledProcessError:
        pass


def git_stage(claude_md_repo: Path, target: Path) -> None:
    """Stage a path in the claude.md repository."""
    try:
        subprocess.run(
            ["git", "add", "-f", str(target.relative_to(claude_md_repo))],
            cwd=claude_md_repo,
            check=True,
        )
        print(f"  Staged {target.relative_to(claude_md_repo)} in claude.md repository")
    except subprocess.CalledProcessError:
        print(
            f"Warning: Could not stage {target} in git",
            file=sys.stderr,
        )


def link_directory(local_dir: Path, central_dir: Path, claude_md_repo: Path) -> None:
    """Move a directory to the central repo and symlink back.

    Handles three cases:
      - Already linked: skip
      - Exists centrally but not locally: create symlink
      - Exists locally but not centrally: copy, remove, symlink, stage
    """
    if local_dir.exists() and central_dir.exists():
        if local_dir.is_symlink() and local_dir.resolve() == central_dir.resolve():
            print(f"  {local_dir.name}: already linked")
            return

        print(
            f"Error: Conflict - both {local_dir} and {central_dir} exist",
            file=sys.stderr,
        )
        sys.exit(1)

    if central_dir.exists() and not local_dir.exists():
        local_dir.symlink_to(central_dir)
        print(f"  {local_dir.name}: linked (from central repo)")
        return

    if local_dir.exists() and not central_dir.exists():
        central_dir.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(local_dir, central_dir, symlinks=True)
        print(f"  {local_dir.name}: copied to central repo")

        shutil.rmtree(local_dir)
        local_dir.symlink_to(central_dir)
        print(f"  {local_dir.name}: symlinked back")

        git_stage(claude_md_repo, central_dir)


def handle_claude_dir(repo_root: Path, claude_md_repo: Path, repo_name: str) -> None:
    """Handle the .claude directory for a project."""
    local_claude_dir = repo_root / ".claude"
    claude_md_claude_dir = claude_md_repo / repo_name / ".claude"
    link_directory(local_claude_dir, claude_md_claude_dir, claude_md_repo)


# -- Per-project: add command --------------------------------------------------


def add_command() -> None:
    """Handle the 'add' command."""
    repo_root = get_repo_root()
    repo_name = repo_root.name
    claude_md_repo = get_claude_md_repo()

    print(f"Managing Claude config for: {repo_name}")

    # Handle .claude directory first
    handle_claude_dir(repo_root, claude_md_repo, repo_name)

    # File paths
    local_file = repo_root / "CLAUDE.local.md"
    claude_md_dir = claude_md_repo / repo_name
    claude_md_file = claude_md_dir / "CLAUDE.local.md"

    # Check if both files exist (conflict)
    if local_file.exists() and claude_md_file.exists():
        if local_file.is_symlink() and local_file.resolve() == claude_md_file.resolve():
            print("  CLAUDE.local.md: already linked")
            return

        show_diff(local_file, claude_md_file)
        print(
            f"Error: Conflict - both {local_file} and {claude_md_file} exist",
            file=sys.stderr,
        )
        sys.exit(1)

    # If file exists in claude.md repo but not locally
    if claude_md_file.exists() and not local_file.exists():
        local_file.symlink_to(claude_md_file)
        print("  CLAUDE.local.md: linked (from central repo)")
        return

    # If file exists locally but not in claude.md repo
    if local_file.exists() and not claude_md_file.exists():
        claude_md_dir.mkdir(parents=True, exist_ok=True)

        shutil.copy2(local_file, claude_md_file)
        print("  CLAUDE.local.md: copied to central repo")

        local_file.unlink()
        local_file.symlink_to(claude_md_file)
        print("  CLAUDE.local.md: symlinked back")

        git_stage(claude_md_repo, claude_md_file)
        return

    # Neither file exists - create one with claude CLI
    print("No CLAUDE.local.md file found, creating one with Claude CLI...")

    try:
        with local_file.open("w") as f:
            subprocess.run(
                [
                    "claude",
                    "--print",
                    f"Create a CLAUDE.local.md file for the {repo_name} repository with helpful context and instructions",
                ],
                stdout=f,
                cwd=repo_root,
                check=True,
            )
        print(f"  Created {local_file} with Claude CLI")

        claude_md_dir.mkdir(parents=True, exist_ok=True)
        shutil.move(str(local_file), str(claude_md_file))
        print("  CLAUDE.local.md: moved to central repo")

        local_file.symlink_to(claude_md_file)
        print("  CLAUDE.local.md: symlinked back")

        git_stage(claude_md_repo, claude_md_file)
    except subprocess.CalledProcessError as e:
        print(f"Error: Failed to create file with Claude CLI: {e}", file=sys.stderr)
        sys.exit(1)


# -- Global: skills/commands management ----------------------------------------


def get_global_items(kind: str) -> list[str]:
    """List items in ~/.claude/<kind>/."""
    source_dir = CLAUDE_HOME / kind
    if not source_dir.exists():
        return []
    return sorted(
        d.name
        for d in source_dir.iterdir()
        if d.is_dir() and not d.name.startswith(".")
    )


def get_item_status(kind: str, name: str, claude_md_repo: Path) -> str:
    """Return status of a global item: 'linked', 'local', 'central', 'missing'."""
    local_dir = CLAUDE_HOME / kind / name
    central_dir = claude_md_repo / GLOBAL_DIR / kind / name

    local_exists = local_dir.exists() or local_dir.is_symlink()
    central_exists = central_dir.exists()

    if local_exists and local_dir.is_symlink():
        if central_exists and local_dir.resolve() == central_dir.resolve():
            return "linked"
        return "local"  # symlink pointing elsewhere
    if local_exists and central_exists:
        return "conflict"
    if local_exists:
        return "local"
    if central_exists:
        return "central"
    return "missing"


def list_global_command(kind: str) -> None:
    """List global items and their management status."""
    claude_md_repo = get_claude_md_repo()
    central_dir = claude_md_repo / GLOBAL_DIR / kind

    # Collect all known items from both local and central
    names: set[str] = set()
    local_dir = CLAUDE_HOME / kind
    if local_dir.exists():
        names.update(
            d.name
            for d in local_dir.iterdir()
            if d.is_dir() and not d.name.startswith(".")
        )
    if central_dir.exists():
        names.update(
            d.name
            for d in central_dir.iterdir()
            if d.is_dir() and not d.name.startswith(".")
        )

    if not names:
        print(f"No {kind} found.")
        return

    status_symbols = {
        "linked": "->",
        "local": "  ",
        "central": "??",
        "conflict": "!!",
    }

    print(f"{'Status':<10} {kind.rstrip('s').title()}")
    print(f"{'------':<10} {'----'}")
    for name in sorted(names):
        status = get_item_status(kind, name, claude_md_repo)
        symbol = status_symbols.get(status, "  ")
        print(f"  {symbol:<8} {name}")

    print()
    print("  ->  linked (managed by claude-md)")
    print("      local only (run 'claude-md add-skill <name>' to manage)")
    print("  ??  central only (run 'claude-md add-skill <name>' to restore)")
    print("  !!  conflict (exists in both locations)")


def add_global_item(kind: str, name: str) -> None:
    """Add a single global item to central management."""
    claude_md_repo = get_claude_md_repo()
    local_dir = CLAUDE_HOME / kind / name
    central_dir = claude_md_repo / GLOBAL_DIR / kind / name

    status = get_item_status(kind, name, claude_md_repo)

    if status == "linked":
        print(f"  {name}: already linked")
        return

    if status == "conflict":
        print(
            f"Error: Conflict - {name} exists in both {local_dir} and {central_dir}",
            file=sys.stderr,
        )
        sys.exit(1)

    if status == "central":
        # Exists centrally but not locally -- restore symlink
        local_parent = local_dir.parent
        local_parent.mkdir(parents=True, exist_ok=True)
        local_dir.symlink_to(central_dir)
        print(f"  {name}: linked (restored from central repo)")
        return

    if status == "local":
        # Exists locally but not centrally -- move and symlink
        central_dir.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(local_dir, central_dir, symlinks=True)
        print(f"  {name}: copied to central repo")

        shutil.rmtree(local_dir)
        local_dir.symlink_to(central_dir)
        print(f"  {name}: symlinked back")

        git_stage(claude_md_repo, central_dir)
        return

    print(f"Error: {kind.rstrip('s')} '{name}' not found", file=sys.stderr)
    sys.exit(1)


def add_global_command(kind: str, names: list[str], all_items: bool) -> None:
    """Handle add-skill / add-command."""
    if all_items:
        items = get_global_items(kind)
        if not items:
            print(f"No {kind} found in {CLAUDE_HOME / kind}")
            return
        print(f"Managing all {kind}:")
        for name in items:
            add_global_item(kind, name)
    elif names:
        for name in names:
            add_global_item(kind, name)
    else:
        print("Error: Specify a name or use --all", file=sys.stderr)
        sys.exit(1)


# -- Status overview -----------------------------------------------------------


def status_command() -> None:
    """Show overview of all managed configuration."""
    claude_md_repo = get_claude_md_repo()

    print(f"Central repo: {claude_md_repo}")
    print()

    # List managed projects
    projects = sorted(
        d.name
        for d in claude_md_repo.iterdir()
        if d.is_dir() and not d.name.startswith(".") and d.name != GLOBAL_DIR
    )
    if projects:
        print("Projects:")
        for p in projects:
            print(f"  {p}")
        print()

    # List global items
    global_dir = claude_md_repo / GLOBAL_DIR
    for kind in ("skills", "commands"):
        kind_dir = global_dir / kind
        if kind_dir.exists():
            items = sorted(d.name for d in kind_dir.iterdir() if d.is_dir())
            if items:
                print(f"Global {kind}:")
                for item in items:
                    status = get_item_status(kind, item, claude_md_repo)
                    symbol = "->" if status == "linked" else status
                    print(f"  {symbol:<10} {item}")
                print()


# -- Main ----------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Centralize Claude Code configuration across repositories"
    )
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # add (per-project)
    subparsers.add_parser(
        "add", help="Add/link CLAUDE.local.md and .claude/ for current repository"
    )

    # add-skill
    skill_parser = subparsers.add_parser(
        "add-skill", help="Add global skill(s) to central management"
    )
    skill_parser.add_argument("names", nargs="*", help="Skill name(s) to add")
    skill_parser.add_argument(
        "--all", action="store_true", dest="all_items", help="Add all skills"
    )

    # add-command
    cmd_parser = subparsers.add_parser(
        "add-command", help="Add global command(s) to central management"
    )
    cmd_parser.add_argument("names", nargs="*", help="Command name(s) to add")
    cmd_parser.add_argument(
        "--all", action="store_true", dest="all_items", help="Add all commands"
    )

    # list-skills
    subparsers.add_parser("list-skills", help="List global skills and their status")

    # list-commands
    subparsers.add_parser("list-commands", help="List global commands and their status")

    # status
    subparsers.add_parser("status", help="Show overview of all managed configuration")

    args = parser.parse_args()

    if args.command == "add":
        add_command()
    elif args.command == "add-skill":
        add_global_command("skills", args.names, args.all_items)
    elif args.command == "add-command":
        add_global_command("commands", args.names, args.all_items)
    elif args.command == "list-skills":
        list_global_command("skills")
    elif args.command == "list-commands":
        list_global_command("commands")
    elif args.command == "status":
        status_command()
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
