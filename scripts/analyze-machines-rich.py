#!/usr/bin/env python3
"""
Analyze machine configurations in the onix-core repository with rich formatting.
Shows machine details, tags, deployment targets, and relationships.
"""

import re
import sys
from collections import defaultdict
from pathlib import Path

from rich import box
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.tree import Tree

console = Console()


def parse_machines_nix(file_path: Path) -> dict[str, dict]:
    """Parse the machines.nix file to extract machine information."""
    machines = {}

    with file_path.open() as f:
        content = f.read()

    # Find the machines block
    machines_match = re.search(
        r"machines\s*=\s*{(.*?)^  };", content, re.MULTILINE | re.DOTALL
    )
    if not machines_match:
        return machines

    machines_content = machines_match.group(1)

    # Parse each machine block - need to handle nested braces properly
    lines = machines_content.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        # Look for machine definition start
        match = re.match(r"([\w-]+)\s*=\s*{", line)
        if match:
            machine_name = match.group(1)
            machine_content_lines = []
            brace_count = 1
            i += 1

            # Collect all lines until we balance the braces
            while i < len(lines) and brace_count > 0:
                line = lines[i]
                machine_content_lines.append(line)
                brace_count += line.count("{") - line.count("}")
                i += 1

            machine_content = "\n".join(machine_content_lines)

            machine_info = {
                "name": machine_name,
                "tags": [],
                "deploy": {"targetHost": "", "buildHost": ""},
            }

            # Extract name
            name_match = re.search(r'name\s*=\s*"([^"]+)"', machine_content)
            if name_match:
                machine_info["name"] = name_match.group(1)

            # Extract tags
            tags_match = re.search(r"tags\s*=\s*\[(.*?)\];", machine_content, re.DOTALL)
            if tags_match:
                tags_content = tags_match.group(1)
                # Extract all quoted strings as tags
                tags = re.findall(r'"([^"]+)"', tags_content)
                machine_info["tags"] = tags

            # Extract deploy info - look for the deploy block more carefully
            # Find where deploy starts and extract until its closing brace
            deploy_start = machine_content.find("deploy = {")
            if deploy_start != -1:
                deploy_content = machine_content[deploy_start:]
                # Find the matching closing brace
                brace_count = 0
                deploy_end = -1
                for idx, char in enumerate(deploy_content):
                    if char == "{":
                        brace_count += 1
                    elif char == "}":
                        brace_count -= 1
                        if brace_count == 0:
                            deploy_end = idx
                            break

                if deploy_end != -1:
                    deploy_block = deploy_content[: deploy_end + 1]

                    target_match = re.search(
                        r'targetHost\s*=\s*"([^"]+)"', deploy_block
                    )
                    if target_match:
                        machine_info["deploy"]["targetHost"] = target_match.group(1)

                    build_match = re.search(r'buildHost\s*=\s*"([^"]*)"', deploy_block)
                    if build_match:
                        machine_info["deploy"]["buildHost"] = build_match.group(1)

            machines[machine_name] = machine_info
        else:
            i += 1

    return machines


def analyze_tags(machines: dict[str, dict]) -> dict[str, list[str]]:
    """Analyze tags across all machines."""
    tag_machines = defaultdict(list)

    for machine_name, info in machines.items():
        for tag in info["tags"]:
            tag_machines[tag].append(machine_name)

    return dict(tag_machines)


def create_machines_tree(
    machines: dict[str, dict], filter_tag: str | None = None
) -> Tree:
    """Create a rich tree structure for machine display."""
    tree = Tree("🖥️  Machines", style="bold cyan")

    # Show all machines directly without grouping by owner
    filtered_machines = []
    for machine_name, info in machines.items():
        # Apply tag filter if specified
        if filter_tag and filter_tag not in info["tags"]:
            continue
        filtered_machines.append((machine_name, info))

    # Build tree - show machines directly
    for machine_name, info in sorted(filtered_machines):
        # Machine node with deployment target
        target_host = info["deploy"]["targetHost"]

        if target_host:
            # Check if it contains an IP address
            target_clean = target_host.replace("root@", "")
            if re.match(r"^\d+\.\d+\.\d+\.\d+$", target_clean):
                target_style = "yellow"
                target_icon = "🌐"
            else:
                target_style = "green"
                target_icon = "📍"
            target_display = target_host
        else:
            target_style = "dim"
            target_icon = "❓"
            target_display = "(no target)"

        machine_text = Text(f"💻 {machine_name} ", style="bold blue")
        machine_text.append(f"{target_icon} {target_display}", style=target_style)

        # Add SSH indicator
        if "sshd" in info["tags"]:
            machine_text.append(" 🔐", style="green")

        machine_node = tree.add(machine_text)

        # Add tags
        if info["tags"]:
            tags_by_type = {
                "tailnet": [],
                "hardware": [],
                "ui": [],
                "service": [],
                "other": [],
            }

            for tag in info["tags"]:
                if tag.startswith("tailnet-"):
                    tags_by_type["tailnet"].append(tag)
                elif tag in ["laptop", "desktop", "wsl", "nvidia"]:
                    tags_by_type["hardware"].append(tag)
                elif tag in ["hyprland"]:
                    tags_by_type["ui"].append(tag)
                elif "server" in tag or tag in [
                    "prometheus",
                    "monitoring",
                    "log-collector",
                    "nix-cache",
                    "onix-cache",
                    "wiki-js",
                ]:
                    tags_by_type["service"].append(tag)
                else:
                    tags_by_type["other"].append(tag)

            tags_text = Text()
            tag_icons = {
                "tailnet": ("🔗", "cyan"),
                "hardware": ("🖥️", "yellow"),
                "ui": ("🎨", "magenta"),
                "service": ("⚙️", "green"),
                "other": ("🏷️", "dim"),
            }

            for tag_type, tags in tags_by_type.items():
                if tags:
                    icon, color = tag_icons[tag_type]
                    for tag in sorted(tags):
                        if tags_text:
                            tags_text.append(" ", style="dim")
                        tags_text.append(f"{icon} {tag}", style=color)

            if tags_text:
                machine_node.add(tags_text)

    return tree


def create_tag_table(tag_machines: dict[str, list[str]]) -> Table:
    """Create a table showing tag usage."""
    # Group tags by category
    tag_categories = {
        "Tailnet": {},
        "Hardware": {},
        "UI": {},
        "Service": {},
        "Other": {},
    }

    for tag, machines in tag_machines.items():
        if tag.startswith("tailnet-"):
            tag_categories["Tailnet"][tag] = machines
        elif tag in ["laptop", "desktop", "wsl", "nvidia"]:
            tag_categories["Hardware"][tag] = machines
        elif tag in ["hyprland"]:
            tag_categories["UI"][tag] = machines
        elif "server" in tag or tag in [
            "prometheus",
            "monitoring",
            "log-collector",
            "nix-cache",
            "onix-cache",
            "wiki-js",
            "traefik-desktop",
            "traefik-homepage",
            "static-test",
            "static-demo",
            "seaweedfs-master",
            "seaweedfs-volume",
        ]:
            tag_categories["Service"][tag] = machines
        else:
            tag_categories["Other"][tag] = machines

    table = Table(title="🏷️  Tag Usage", box=box.ROUNDED)
    table.add_column("Category", style="cyan", no_wrap=True)
    table.add_column("Tag", style="yellow")
    table.add_column("Count", style="magenta", justify="center")
    table.add_column("Machines", style="green")

    for category, tags in tag_categories.items():
        if tags:
            first = True
            for tag, machines in sorted(tags.items()):
                table.add_row(
                    category if first else "",
                    tag,
                    str(len(machines)),
                    ", ".join(sorted(machines)),
                )
                first = False
            if category != "Other":  # Add separator except after last category
                table.add_row("", "", "", "", style="dim")

    return table


def create_deployment_table(machines: dict[str, dict]) -> Table:
    """Create a table showing deployment information."""
    table = Table(title="🚀 Deployment Configuration", box=box.ROUNDED)
    table.add_column("Machine", style="cyan", no_wrap=True)
    table.add_column("targetHost", style="green")
    table.add_column("buildHost", style="magenta")

    # Sort machines by name
    sorted_machines = sorted(machines.items())

    for machine_name, info in sorted_machines:
        target_host = info["deploy"]["targetHost"]
        build_host = (
            info["deploy"]["buildHost"] if info["deploy"]["buildHost"] else '""'
        )

        # Style the targetHost based on type
        if target_host:
            # Check if it's an IP address (after removing root@)
            target_clean = target_host.replace("root@", "")
            if re.match(r"^\d+\.\d+\.\d+\.\d+$", target_clean):
                target_style = "yellow"
            else:
                target_style = "green"
            target_text = Text(target_host, style=target_style)
        else:
            target_text = Text('""', style="dim")

        # Style the buildHost
        build_text = Text(build_host, style="dim" if build_host == '""' else "magenta")

        table.add_row(machine_name, target_text, build_text)

    return table


def main() -> int | None:
    # Try to find the repository root
    current_dir = Path.cwd()

    # Walk up the directory tree to find the repository root
    repo_root = None
    check_dir = current_dir
    while check_dir != check_dir.parent:
        if (check_dir / "inventory" / "core" / "machines.nix").exists():
            repo_root = check_dir
            break
        check_dir = check_dir.parent

    if repo_root is None:
        # If not found, try current directory
        if (current_dir / "inventory" / "core" / "machines.nix").exists():
            repo_root = current_dir
        else:
            console.print(
                "[red]Error: Could not find inventory/core/machines.nix[/red]"
            )
            console.print(
                "[yellow]Please run this command from within the onix-core repository[/yellow]"
            )
            sys.exit(1)

    machines_path = repo_root / "inventory" / "core" / "machines.nix"

    # Parse and analyze
    with console.status("[bold green]Parsing machines.nix..."):
        machines = parse_machines_nix(machines_path)

    with console.status("[bold green]Analyzing tags..."):
        tag_machines = analyze_tags(machines)

    # Display header
    console.print(
        Panel.fit(
            "[bold cyan]Machine Configuration Analysis[/bold cyan]\n"
            f"[dim]Configuration: {machines_path}[/dim]",
            box=box.DOUBLE,
        )
    )
    console.print()

    # Display machines tree
    machines_tree = create_machines_tree(machines)
    console.print(machines_tree)
    console.print()

    # Display tag table
    tag_table = create_tag_table(tag_machines)
    console.print(tag_table)
    console.print()

    # Display deployment table
    console.print(create_deployment_table(machines))
    console.print()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Analyze machine configurations")
    parser.add_argument("--tag", help="Filter machines by specific tag")
    args = parser.parse_args()

    # If tag filter is specified, show filtered tree
    if args.tag:
        # Re-run the scan with filter
        current_dir = Path.cwd()
        repo_root = None
        check_dir = current_dir
        while check_dir != check_dir.parent:
            if (check_dir / "inventory" / "core" / "machines.nix").exists():
                repo_root = check_dir
                break
            check_dir = check_dir.parent

        if (
            repo_root is None
            and (current_dir / "inventory" / "core" / "machines.nix").exists()
        ):
            repo_root = current_dir

        if repo_root:
            machines_path = repo_root / "inventory" / "core" / "machines.nix"
            machines = parse_machines_nix(machines_path)

            console.print(
                Panel.fit(
                    f"[bold]Filtered View[/bold]\ntag=[yellow]{args.tag}[/yellow]",
                    box=box.DOUBLE,
                )
            )
            console.print()

            filtered_tree = create_machines_tree(machines, args.tag)
            console.print(filtered_tree)

            # Show how many machines have this tag
            filtered_count = sum(
                1 for info in machines.values() if args.tag in info["tags"]
            )
            console.print()
            console.print(
                f"[dim]Found {filtered_count} machines with tag '{args.tag}'[/dim]"
            )
        else:
            console.print("[red]Error: Could not find repository root[/red]")
    else:
        main()
