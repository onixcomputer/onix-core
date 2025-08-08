#!/usr/bin/env python3
"""
Analyze SOPS variable ownership in the onix-core repository with rich formatting.
Shows which variables are owned by which users, groups, and shared access.
"""

import sys
from collections import defaultdict
from pathlib import Path

from rich import box
from rich.columns import Columns
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.tree import Tree

console = Console()


def scan_vars_directory(vars_path: Path) -> dict[str, dict[str, set[str]]]:
    """
    Scan the vars directory and collect ownership information.
    Returns a dictionary mapping variable paths to their ownership info.
    """
    ownership = {}

    # Scan per-machine variables
    per_machine_path = vars_path / "per-machine"
    if per_machine_path.exists():
        for machine_dir in per_machine_path.iterdir():
            if machine_dir.is_dir():
                scan_machine_vars(
                    machine_dir, ownership, f"per-machine/{machine_dir.name}"
                )

    # Scan shared variables
    shared_path = vars_path / "shared"
    if shared_path.exists():
        scan_machine_vars(shared_path, ownership, "shared")

    return ownership


def scan_machine_vars(base_path: Path, ownership: dict, prefix: str) -> None:
    """Recursively scan for variables and their ownership."""
    for item in base_path.iterdir():
        if item.is_dir():
            # Check if this is a variable (has secret or value file)
            has_secret = (item / "secret").exists()
            has_value = (item / "value").exists()

            if has_secret or has_value:
                var_path = f"{prefix}/{item.relative_to(base_path)}"
                ownership[var_path] = {
                    "users": set(),
                    "machines": set(),
                    "groups": set(),
                    "type": "secret" if has_secret else "value",
                }

                # Collect users
                users_dir = item / "users"
                if users_dir.exists():
                    for user in users_dir.iterdir():
                        if user.is_file() or user.is_symlink():
                            ownership[var_path]["users"].add(user.name)

                # Collect machines
                machines_dir = item / "machines"
                if machines_dir.exists():
                    for machine in machines_dir.iterdir():
                        if machine.is_file() or machine.is_symlink():
                            ownership[var_path]["machines"].add(machine.name)
            else:
                # Recurse into subdirectories
                scan_machine_vars(item, ownership, f"{prefix}/{item.name}")


def analyze_groups(groups_path: Path) -> dict[str, dict[str, set[str]]]:
    """Analyze group memberships from the groups directory."""
    groups = {}

    if not groups_path.exists():
        return groups

    for group_dir in groups_path.iterdir():
        if group_dir.is_dir():
            group_name = group_dir.name
            groups[group_name] = {"users": set(), "machines": set()}

            # Check for users in group
            users_dir = group_dir / "users"
            if users_dir.exists():
                for user in users_dir.iterdir():
                    if user.is_file() or user.is_symlink():
                        groups[group_name]["users"].add(user.name)

            # Check for machines in group
            machines_dir = group_dir / "machines"
            if machines_dir.exists():
                for machine in machines_dir.iterdir():
                    if machine.is_file() or machine.is_symlink():
                        groups[group_name]["machines"].add(machine.name)

    return groups


def create_ownership_tree(
    ownership: dict[str, dict[str, set[str]]],
    filter_user: str | None = None,
    filter_machine: str | None = None,
) -> Tree:
    """Create a rich tree structure for ownership display."""
    tree = Tree("📁 SOPS Variables", style="bold cyan")

    # Group by top-level directory
    grouped = defaultdict(dict)
    for var_path, info in ownership.items():
        # Apply filters if specified
        if filter_user and filter_user not in info["users"]:
            continue
        if filter_machine and filter_machine not in info["machines"]:
            continue

        parts = var_path.split("/")
        if parts[0] == "per-machine":
            grouped[f"per-machine/{parts[1]}"]["/".join(parts[2:])] = info
        else:
            grouped["shared"]["/".join(parts[1:])] = info

    # Build tree
    for group_path in sorted(grouped.keys()):
        if group_path.startswith("per-machine/"):
            machine_name = group_path.split("/")[1]
            group_node = tree.add(f"💻 {machine_name}", style="bold yellow")
        else:
            group_node = tree.add("🌐 shared", style="bold green")

        for var_name in sorted(grouped[group_path].keys()):
            info = grouped[group_path][var_name]

            # Create variable node with type indicator
            if info["type"] == "secret":
                var_text = Text(f"🔐 {var_name}", style="red")
            else:
                var_text = Text(f"📄 {var_name}", style="blue")

            var_node = group_node.add(var_text)

            # Add ownership info
            if info["users"]:
                users_text = Text("👤 Users: ", style="dim") + Text(
                    ", ".join(sorted(info["users"])), style="cyan"
                )
                var_node.add(users_text)
            if info["machines"]:
                machines_text = Text("🖥️  Machines: ", style="dim") + Text(
                    ", ".join(sorted(info["machines"])), style="yellow"
                )
                var_node.add(machines_text)

    return tree


def create_stats_table(ownership: dict[str, dict[str, set[str]]]) -> Table:
    """Create a statistics table."""
    table = Table(title="📊 Summary Statistics", box=box.ROUNDED)
    table.add_column("Metric", style="cyan", no_wrap=True)
    table.add_column("Value", style="magenta")

    total_vars = len(ownership)
    total_secrets = sum(1 for info in ownership.values() if info["type"] == "secret")
    total_values = sum(1 for info in ownership.values() if info["type"] == "value")

    table.add_row("Total Variables", str(total_vars))
    table.add_row("🔐 Secrets", str(total_secrets))
    table.add_row("📄 Values", str(total_values))

    # User statistics
    all_users = set()
    for info in ownership.values():
        all_users.update(info["users"])

    table.add_row("👤 Total Users", str(len(all_users)))

    # Machine statistics
    all_machines = set()
    for info in ownership.values():
        all_machines.update(info["machines"])

    table.add_row("💻 Total Machines", str(len(all_machines)))

    return table


def create_user_table(ownership: dict[str, dict[str, set[str]]]) -> Table:
    """Create a table showing per-user access."""
    table = Table(title="👤 User Access Summary", box=box.ROUNDED)
    table.add_column("User", style="cyan", no_wrap=True)
    table.add_column("Total Vars", style="magenta")
    table.add_column("Secrets", style="red")
    table.add_column("Values", style="blue")

    # Collect user stats
    user_stats = defaultdict(lambda: {"total": 0, "secrets": 0, "values": 0})

    for info in ownership.values():
        for user in info["users"]:
            user_stats[user]["total"] += 1
            if info["type"] == "secret":
                user_stats[user]["secrets"] += 1
            else:
                user_stats[user]["values"] += 1

    for user in sorted(user_stats.keys()):
        stats = user_stats[user]
        table.add_row(
            user, str(stats["total"]), str(stats["secrets"]), str(stats["values"])
        )

    return table


def create_machine_table(ownership: dict[str, dict[str, set[str]]]) -> Table:
    """Create a table showing per-machine access."""
    table = Table(title="💻 Machine Access Summary", box=box.ROUNDED)
    table.add_column("Machine", style="yellow", no_wrap=True)
    table.add_column("Total Vars", style="magenta")
    table.add_column("Secrets", style="red")
    table.add_column("Values", style="blue")

    # Collect machine stats
    machine_stats = defaultdict(lambda: {"total": 0, "secrets": 0, "values": 0})

    for info in ownership.values():
        for machine in info["machines"]:
            machine_stats[machine]["total"] += 1
            if info["type"] == "secret":
                machine_stats[machine]["secrets"] += 1
            else:
                machine_stats[machine]["values"] += 1

    for machine in sorted(machine_stats.keys()):
        stats = machine_stats[machine]
        table.add_row(
            machine, str(stats["total"]), str(stats["secrets"]), str(stats["values"])
        )

    return table


def create_groups_panel(groups: dict[str, dict[str, set[str]]]) -> Panel | None:
    """Create a panel showing group memberships."""
    if not groups:
        return None

    group_tree = Tree("👥 Group Memberships", style="bold cyan")

    for group_name in sorted(groups.keys()):
        members = groups[group_name]
        group_node = group_tree.add(f"🏷️  {group_name}", style="bold green")

        if members["users"]:
            users_text = Text("👤 Users: ", style="dim") + Text(
                ", ".join(sorted(members["users"])), style="cyan"
            )
            group_node.add(users_text)

        if members["machines"]:
            machines_text = Text("💻 Machines: ", style="dim") + Text(
                ", ".join(sorted(members["machines"])), style="yellow"
            )
            group_node.add(machines_text)

    return Panel(group_tree, box=box.ROUNDED)


def main() -> int | None:
    # Try to find the repository root
    current_dir = Path.cwd()

    # Walk up the directory tree to find the repository root
    repo_root = None
    check_dir = current_dir
    while check_dir != check_dir.parent:
        if (check_dir / "vars").exists() and (check_dir / "sops").exists():
            repo_root = check_dir
            break
        check_dir = check_dir.parent

    if repo_root is None:
        # If not found, try current directory
        if (current_dir / "vars").exists():
            repo_root = current_dir
        else:
            console.print(
                "[red]Error: Could not find repository root with 'vars' directory[/red]"
            )
            console.print(
                "[yellow]Please run this command from within the onix-core repository[/yellow]"
            )
            sys.exit(1)

    vars_path = repo_root / "vars"
    groups_path = repo_root / "sops" / "groups"

    # Scan and analyze
    with console.status("[bold green]Scanning variables directory..."):
        ownership = scan_vars_directory(vars_path)

    with console.status("[bold green]Analyzing groups..."):
        groups = analyze_groups(groups_path)

    # Display header
    console.print(
        Panel.fit(
            "[bold cyan]SOPS Variable Ownership Report[/bold cyan]\n"
            f"[dim]Repository: {repo_root}[/dim]",
            box=box.DOUBLE,
        )
    )
    console.print()

    # Display ownership tree
    console.print(create_ownership_tree(ownership))
    console.print()

    # Display statistics in columns
    stats_table = create_stats_table(ownership)
    user_table = create_user_table(ownership)
    machine_table = create_machine_table(ownership)

    console.print(Columns([stats_table, user_table]))
    console.print()
    console.print(machine_table)
    console.print()

    # Display groups if available
    groups_panel = create_groups_panel(groups)
    if groups_panel:
        console.print(groups_panel)
        console.print()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Analyze SOPS variable ownership")
    parser.add_argument("--user", help="Filter by specific user")
    parser.add_argument("--machine", help="Filter by specific machine")
    args = parser.parse_args()

    # If filters are specified, show filtered tree
    if args.user or args.machine:
        # Re-run the scan with filters
        current_dir = Path.cwd()
        repo_root = None
        check_dir = current_dir
        while check_dir != check_dir.parent:
            if (check_dir / "vars").exists() and (check_dir / "sops").exists():
                repo_root = check_dir
                break
            check_dir = check_dir.parent

        if repo_root is None and (current_dir / "vars").exists():
            repo_root = current_dir

        if repo_root:
            vars_path = repo_root / "vars"
            ownership = scan_vars_directory(vars_path)

            filter_text = []
            if args.user:
                filter_text.append(f"user=[cyan]{args.user}[/cyan]")
            if args.machine:
                filter_text.append(f"machine=[yellow]{args.machine}[/yellow]")

            console.print(
                Panel.fit(
                    f"[bold]Filtered View[/bold]\n{' and '.join(filter_text)}",
                    box=box.DOUBLE,
                )
            )
            console.print()

            filtered_tree = create_ownership_tree(ownership, args.user, args.machine)
            console.print(filtered_tree)
        else:
            console.print("[red]Error: Could not find repository root[/red]")
    else:
        main()
