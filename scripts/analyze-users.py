#!/usr/bin/env python3
"""
Analyze user configurations in the onix-core repository.
Shows user details, roles, machines, home-manager profiles, and relationships.
"""

import re
import sys
from collections import defaultdict
from pathlib import Path


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


def analyze_users(users: dict[str, dict]) -> dict[str, list | set | dict]:
    """Analyze user configurations and extract insights."""
    analysis = {
        "role_distribution": defaultdict(list),
        "shell_distribution": defaultdict(list),
        "profile_usage": defaultdict(set),
        "machine_users": defaultdict(list),
        "group_usage": defaultdict(set),
        "cross_machine_access": [],
    }

    for username, user_info in users.items():
        # Analyze machine roles
        for machine_name, machine_info in user_info["machines"].items():
            role = machine_info["role"]
            analysis["role_distribution"][role].append(f"{username}@{machine_name}")
            analysis["machine_users"][machine_name].append((username, role))

            # Shell distribution
            shell = machine_info["shell"]
            analysis["shell_distribution"][shell].append(f"{username}@{machine_name}")

            # Profile usage
            for profile in machine_info["homeManager"]["profiles"]:
                analysis["profile_usage"][profile].add(username)

        # Group usage
        for group in user_info["defaultGroups"]:
            analysis["group_usage"][group].add(username)

        # Check for cross-machine access (users on machines they don't own)
        for machine_name, machine_info in user_info["machines"].items():
            if (
                not machine_name.startswith(username.replace("r", ""))
                and machine_info["role"] != "owner"
            ):
                analysis["cross_machine_access"].append(
                    {
                        "user": username,
                        "machine": machine_name,
                        "role": machine_info["role"],
                    }
                )

    return analysis


def print_users_report(
    users: dict[str, dict], analysis: dict[str, list | set | dict]
) -> None:
    """Print a formatted users report."""
    print("User Configuration Report")
    print("=" * 80)

    # Print user details
    print("\n### User Details ###")
    for username in sorted(users.keys()):
        user = users[username]
        print(f"\n{username} ({user['description']}):")
        print(f"  UID: {user['defaultUid']}")
        print(f"  Groups: {', '.join(user['defaultGroups'])}")
        print(f"  SSH Keys: {len(user['sshAuthorizedKeys'])} key(s)")
        print(f"  Machines: {len(user['machines'])} machine(s)")

        # Show machine details
        for machine_name in sorted(user["machines"].keys()):
            machine = user["machines"][machine_name]
            print(f"    - {machine_name}:")
            print(f"        Role: {machine['role']}")
            print(f"        Shell: {machine['shell']}")
            if machine["homeManager"]["enable"]:
                print(
                    f"        Home Manager: {', '.join(machine['homeManager']['profiles'])}"
                )

    # Print role analysis
    print("\n### Role Distribution ###")
    for role in sorted(analysis["role_distribution"].keys()):
        assignments = analysis["role_distribution"][role]
        print(f"\n{role}: {len(assignments)} assignments")
        for assignment in sorted(assignments):
            print(f"  - {assignment}")

    # Print shell preferences
    print("\n### Shell Preferences ###")
    for shell in sorted(analysis["shell_distribution"].keys()):
        users_list = analysis["shell_distribution"][shell]
        print(f"{shell}: {len(users_list)} users")

    # Print home-manager profile usage
    print("\n### Home Manager Profile Usage ###")
    for profile in sorted(analysis["profile_usage"].keys()):
        users_set = analysis["profile_usage"][profile]
        print(f"{profile}: {', '.join(sorted(users_set))} ({len(users_set)} users)")

    # Print machine access summary
    print("\n### Machine Access Summary ###")
    for machine in sorted(analysis["machine_users"].keys()):
        users_list = analysis["machine_users"][machine]
        print(f"\n{machine}:")
        for username, role in sorted(users_list):
            print(f"  - {username} ({role})")

    # Print cross-machine access
    if analysis["cross_machine_access"]:
        print("\n### Cross-Machine Access ###")
        print("Users with access to machines they don't own:")
        for access in analysis["cross_machine_access"]:
            print(f"  - {access['user']} → {access['machine']} ({access['role']})")

    # Print group membership
    print("\n### Group Membership ###")
    for group in sorted(analysis["group_usage"].keys()):
        members = analysis["group_usage"][group]
        print(f"{group}: {', '.join(sorted(members))}")

    # Print summary statistics
    print("\n### Summary Statistics ###")
    print(f"Total users: {len(users)}")
    print(
        f"Total machine assignments: {sum(len(u['machines']) for u in users.values())}"
    )
    print(
        f"Average machines per user: {sum(len(u['machines']) for u in users.values()) / len(users):.1f}"
    )

    # Count by role
    role_counts = defaultdict(int)
    for assignments in analysis["role_distribution"].values():
        role_counts[len(assignments)] = len(assignments)

    print("\nRole distribution:")
    for role, count in analysis["role_distribution"].items():
        print(f"  {role}: {len(count)} assignments")


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
            print("Error: Could not find inventory/core/users.nix")
            print("Please run this command from within the onix-core repository")
            sys.exit(1)

    users_path = repo_root / "inventory" / "core" / "users.nix"

    # Parse and analyze
    print("Parsing users.nix...")
    users = parse_users_nix(users_path)

    print("Analyzing user configurations...")
    analysis = analyze_users(users)

    # Generate report
    print_users_report(users, analysis)


if __name__ == "__main__":
    main()
