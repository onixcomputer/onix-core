#!/usr/bin/env python3
"""
Analyze user configurations in the onix-core repository with rich formatting.
Shows user details, roles, machines, home-manager profiles, and relationships.
"""

import re
import sys
from collections import defaultdict
from pathlib import Path

from rich import box
from rich.console import Console
from rich.panel import Panel
from rich.text import Text
from rich.tree import Tree

console = Console()


def find_matching_brace(content: str, start_pos: int) -> int:
    """Find the position of the closing brace that matches the opening brace at start_pos."""
    if content[start_pos] != "{":
        return -1

    count = 1
    pos = start_pos + 1

    while pos < len(content) and count > 0:
        if content[pos] == "{":
            count += 1
        elif content[pos] == "}":
            count -= 1
        pos += 1

    return pos - 1 if count == 0 else -1


def parse_users_nix(file_path: Path) -> dict[str, dict]:
    """Parse the users.nix file to extract user information."""
    users = {}

    with file_path.open() as f:
        content = f.read()

    # Find all user assignments at the top level
    # Look for pattern: word = { at the beginning of a line after the function header
    user_starts = []
    lines = content.split("\n")

    in_function = False
    brace_count = 0

    for i, line in enumerate(lines):
        stripped = line.strip()

        # Skip the function header
        if stripped.startswith("_:"):
            in_function = True
            continue

        # Count braces BEFORE checking for user assignments (this is the key fix!)
        brace_count += line.count("{") - line.count("}")

        if in_function and brace_count == 1:
            # Look for user assignments at the top level
            match = re.match(r"^  (\w+)\s*=\s*\{", line)
            if match:
                username = match.group(1)
                # Check if the next few lines contain 'description'
                description_found = False
                for j in range(i + 1, min(i + 5, len(lines))):
                    if "description" in lines[j]:
                        description_found = True
                        break

                if description_found:
                    user_starts.append((i, username))

    # Now extract each user block
    for idx, (start_line, username) in enumerate(user_starts):
        # Find the end of this user block
        if idx + 1 < len(user_starts):
            end_line = user_starts[idx + 1][0] - 1
        else:
            # Last user - find the closing brace
            end_line = len(lines) - 2  # Skip the final closing brace

        # Extract the user block
        user_lines = lines[start_line : end_line + 1]
        user_block = "\n".join(user_lines)

        user_info = {
            "name": username,
            "description": "",
            "defaultUid": None,
            "defaultGroups": [],
            "sshAuthorizedKeys": [],
            "machines": {},
        }

        # Extract description
        desc_match = re.search(r'description\s*=\s*"([^"]+)"', user_block)
        if desc_match:
            user_info["description"] = desc_match.group(1)

        # Extract defaultUid
        uid_match = re.search(r"defaultUid\s*=\s*(\d+)", user_block)
        if uid_match:
            user_info["defaultUid"] = int(uid_match.group(1))

        # Extract defaultGroups
        groups_match = re.search(
            r"defaultGroups\s*=\s*\[(.*?)\];", user_block, re.DOTALL
        )
        if groups_match:
            groups_content = groups_match.group(1)
            groups = re.findall(r'"([^"]+)"', groups_content)
            user_info["defaultGroups"] = groups

        # Extract SSH keys
        ssh_match = re.search(
            r"sshAuthorizedKeys\s*=\s*\[(.*?)\];", user_block, re.DOTALL
        )
        if ssh_match:
            ssh_content = ssh_match.group(1)
            keys = re.findall(r'"([^"]+)"', ssh_content)
            user_info["sshAuthorizedKeys"] = keys

        # Extract machines configuration
        machines_match = re.search(r"machines\s*=\s*\{", user_block)
        if machines_match:
            # Find the start of the machines block
            machines_start = machines_match.end() - 1
            machines_end = find_matching_brace(user_block, machines_start)

            if machines_end > machines_start:
                machines_content = user_block[machines_start + 1 : machines_end]

                # Parse each machine - only match at proper indentation (6 spaces)
                machine_pattern = r"\n\s{6}([\w-]+)\s*=\s*\{"
                for machine_match in re.finditer(machine_pattern, machines_content):
                    machine_name = machine_match.group(1)
                    machine_start = machine_match.end() - 1
                    machine_end = find_matching_brace(machines_content, machine_start)

                    if machine_end > machine_start:
                        machine_block = machines_content[
                            machine_start : machine_end + 1
                        ]

                        machine_info = {
                            "role": "user",
                            "shell": "bash",
                            "homeManager": {"enable": False, "profiles": []},
                        }

                        # Extract role
                        role_match = re.search(r'role\s*=\s*"([^"]+)"', machine_block)
                        if role_match:
                            machine_info["role"] = role_match.group(1)

                        # Extract shell
                        shell_match = re.search(r'shell\s*=\s*"([^"]+)"', machine_block)
                        if shell_match:
                            machine_info["shell"] = shell_match.group(1)

                        # Extract homeManager settings
                        hm_match = re.search(r"homeManager\s*=\s*\{", machine_block)
                        if hm_match:
                            hm_start = hm_match.end() - 1
                            hm_end = find_matching_brace(machine_block, hm_start)

                            if hm_end > hm_start:
                                hm_content = machine_block[hm_start : hm_end + 1]

                                # Extract enable
                                enable_match = re.search(
                                    r"enable\s*=\s*(\w+)", hm_content
                                )
                                if enable_match:
                                    machine_info["homeManager"]["enable"] = (
                                        enable_match.group(1) == "true"
                                    )

                                # Extract profiles
                                profiles_match = re.search(
                                    r"profiles\s*=\s*\[(.*?)\];", hm_content, re.DOTALL
                                )
                                if profiles_match:
                                    profiles_content = profiles_match.group(1)
                                    profiles = re.findall(
                                        r'"([^"]+)"', profiles_content
                                    )
                                    machine_info["homeManager"]["profiles"] = profiles

                        user_info["machines"][machine_name] = machine_info

        users[username] = user_info

    return users


def create_user_tree(
    users: dict[str, dict],
    filter_machine: str | None = None,
    filter_profile: str | None = None,
) -> Tree:
    """Create a rich tree structure for user display."""
    tree = Tree("👥 Users", style="bold cyan")

    for username in sorted(users.keys()):
        user = users[username]

        # Apply filters
        if filter_machine:
            if filter_machine not in user["machines"]:
                continue

        if filter_profile:
            has_profile = False
            for machine_info in user["machines"].values():
                if filter_profile in machine_info["homeManager"]["profiles"]:
                    has_profile = True
                    break
            if not has_profile:
                continue

        # User node
        user_text = Text(f"👤 {username} ", style="bold yellow")
        user_text.append(f"({user['description']})", style="dim")
        user_text.append(f" [UID: {user['defaultUid']}]", style="cyan")
        user_node = tree.add(user_text)

        # Add user details
        if user["defaultGroups"]:
            groups_text = Text("📋 Groups: ", style="dim")
            groups_text.append(", ".join(user["defaultGroups"]), style="green")
            user_node.add(groups_text)

        if user["sshAuthorizedKeys"]:
            ssh_text = Text("🔑 SSH Keys: ", style="dim")
            ssh_text.append(
                f"{len(user['sshAuthorizedKeys'])} authorized", style="magenta"
            )
            user_node.add(ssh_text)

        # Add machines
        if user["machines"]:
            machines_node = user_node.add("💻 Machines", style="bold blue")

            for machine_name in sorted(user["machines"].keys()):
                machine = user["machines"][machine_name]

                # Apply machine filter
                if filter_machine and machine_name != filter_machine:
                    continue

                # Machine details
                shell_icon = (
                    "🐟"
                    if machine["shell"] == "fish"
                    else "🐚"
                    if machine["shell"] == "zsh"
                    else "🔧"
                )

                role_color = (
                    "red"
                    if machine["role"] == "owner"
                    else "yellow"
                    if machine["role"] == "admin"
                    else "dim"
                )
                machine_text = Text(f"├─ {machine_name} ", style="bold")
                machine_text.append(f"[{machine['role']}]", style=role_color)
                machine_text.append(f" {shell_icon} {machine['shell']}", style="cyan")
                machine_node = machines_node.add(machine_text)

                # Home Manager profiles
                if (
                    machine["homeManager"]["enable"]
                    and machine["homeManager"]["profiles"]
                ):
                    profiles_text = Text("   └─ ", style="dim")
                    profile_icons = {
                        "base": "🏠",
                        "dev": "💻",
                        "laptop": "💼",
                        "desktop": "🖥️",
                        "creative": "🎨",
                        "social": "💬",
                        "media": "🎬",
                    }

                    for i, profile in enumerate(machine["homeManager"]["profiles"]):
                        if i > 0:
                            profiles_text.append(" ", style="dim")
                        icon = profile_icons.get(profile, "📦")
                        profiles_text.append(f"{icon} {profile}", style="green")

                    machine_node.add(profiles_text)

    return tree


def create_machine_access_panel(users: dict[str, dict]) -> Panel:
    """Create a panel showing machine access summary."""
    # Collect machine access data
    machine_access = defaultdict(list)
    cross_access = []

    for username, user in users.items():
        for machine_name, machine_info in user["machines"].items():
            machine_access[machine_name].append((username, machine_info["role"]))

            # Check for cross-machine access
            if (
                not machine_name.startswith(username.replace("r", ""))
                and machine_info["role"] != "owner"
            ):
                cross_access.append(
                    {
                        "user": username,
                        "machine": machine_name,
                        "role": machine_info["role"],
                    }
                )

    # Build text
    text = Text()
    text.append("🖥️  Machine Access Overview\n\n", style="bold cyan")

    # Machines with multiple users
    multi_user_machines = [
        (m, users) for m, users in machine_access.items() if len(users) > 1
    ]
    if multi_user_machines:
        text.append("Shared Machines:\n", style="bold yellow")
        for machine, users_list in sorted(multi_user_machines):
            text.append(f"  {machine}: ", style="bold")
            user_texts = []
            for user, role in sorted(users_list):
                user_texts.append(f"{user}[{role}]")
            text.append(", ".join(user_texts) + "\n")

    # Cross-machine access
    if cross_access:
        text.append("\nCross-Machine Access:\n", style="bold yellow")
        for access in cross_access:
            text.append(f"  {access['user']} → {access['machine']} ", style="cyan")
            text.append(f"[{access['role']}]\n", style="yellow")

    return Panel(text, box=box.ROUNDED)


def main() -> int | None:
    # Try to find the repository root
    current_dir = Path.cwd()

    # Walk up the directory tree to find the repository root
    repo_root = None
    check_dir = current_dir
    while check_dir != check_dir.parent:
        if (check_dir / "inventory" / "core" / "users.nix").exists():
            repo_root = check_dir
            break
        check_dir = check_dir.parent

    if repo_root is None:
        # If not found, try current directory
        if (current_dir / "inventory" / "core" / "users.nix").exists():
            repo_root = current_dir
        else:
            console.print("[red]Error: Could not find inventory/core/users.nix[/red]")
            console.print(
                "[yellow]Please run this command from within the onix-core repository[/yellow]"
            )
            sys.exit(1)

    users_path = repo_root / "inventory" / "core" / "users.nix"

    # Parse and analyze
    with console.status("[bold green]Parsing users.nix..."):
        users = parse_users_nix(users_path)

    # Display header
    console.print(
        Panel.fit(
            "[bold cyan]User Configuration Analysis[/bold cyan]\n"
            f"[dim]Configuration: {users_path}[/dim]",
            box=box.DOUBLE,
        )
    )
    console.print()

    # Display user tree
    console.print(create_user_tree(users))
    console.print()

    # Display machine access panel
    console.print(create_machine_access_panel(users))
    console.print()

    # Interactive mode hint
    console.print(
        Panel(
            "[dim]💡 Tips: You can filter the view\n"
            "• By machine: users-analyzer-rich --machine britton-fw\n"
            "• By profile: users-analyzer-rich --profile dev[/dim]",
            box=box.ROUNDED,
            style="dim",
        )
    )


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Analyze user configurations")
    parser.add_argument("--machine", help="Filter by specific machine")
    parser.add_argument("--profile", help="Filter by home-manager profile")
    args = parser.parse_args()

    # If filters are specified, show filtered tree
    if args.machine or args.profile:
        # Re-run the scan with filters
        current_dir = Path.cwd()
        repo_root = None
        check_dir = current_dir
        while check_dir != check_dir.parent:
            if (check_dir / "inventory" / "core" / "users.nix").exists():
                repo_root = check_dir
                break
            check_dir = check_dir.parent

        if (
            repo_root is None
            and (current_dir / "inventory" / "core" / "users.nix").exists()
        ):
            repo_root = current_dir

        if repo_root:
            users_path = repo_root / "inventory" / "core" / "users.nix"
            users = parse_users_nix(users_path)

            filter_text = []
            if args.machine:
                filter_text.append(f"machine=[yellow]{args.machine}[/yellow]")
            if args.profile:
                filter_text.append(f"profile=[green]{args.profile}[/green]")

            console.print(
                Panel.fit(
                    f"[bold]Filtered View[/bold]\n{' and '.join(filter_text)}",
                    box=box.DOUBLE,
                )
            )
            console.print()

            filtered_tree = create_user_tree(users, args.machine, args.profile)
            console.print(filtered_tree)
        else:
            console.print("[red]Error: Could not find repository root[/red]")
    else:
        main()
