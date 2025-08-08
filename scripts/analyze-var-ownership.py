#!/usr/bin/env python3
"""
Analyze SOPS variable ownership in the onix-core repository.
Shows which variables are owned by which users, groups, and shared access.
"""

import sys
from collections import defaultdict
from pathlib import Path


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


def print_ownership_report(
    ownership: dict[str, dict[str, set[str]]], groups: dict[str, dict[str, set[str]]]
) -> None:
    """Print a formatted ownership report."""
    print("SOPS Variable Ownership Report")
    print("=" * 80)

    # Group variables by ownership type
    user_owned = defaultdict(list)
    machine_owned = defaultdict(list)
    shared_vars = []

    for var_path, info in ownership.items():
        if len(info["users"]) == 1 and len(info["machines"]) == 0:
            user = next(iter(info["users"]))
            user_owned[user].append(var_path)
        elif len(info["machines"]) == 1 and len(info["users"]) == 0:
            machine = next(iter(info["machines"]))
            machine_owned[machine].append(var_path)
        else:
            shared_vars.append((var_path, info))

    # Print user-owned variables
    print("\n### Variables Owned by Users ###")
    for user, vars_list in sorted(user_owned.items()):
        print(f"\n{user}:")
        for var in sorted(vars_list):
            var_type = ownership[var]["type"]
            print(f"  - {var} ({var_type})")

    # Print machine-owned variables
    print("\n### Variables Owned by Machines ###")
    for machine, vars_list in sorted(machine_owned.items()):
        print(f"\n{machine}:")
        for var in sorted(vars_list):
            var_type = ownership[var]["type"]
            print(f"  - {var} ({var_type})")

    # Print shared variables
    print("\n### Shared Variables ###")
    for var_path, info in sorted(shared_vars):
        print(f"\n{var_path} ({info['type']}):")
        if info["users"]:
            print(f"  Users: {', '.join(sorted(info['users']))}")
        if info["machines"]:
            print(f"  Machines: {', '.join(sorted(info['machines']))}")

    # Print group information if available
    if groups:
        print("\n### Group Memberships ###")
        for group_name, members in sorted(groups.items()):
            print(f"\n{group_name}:")
            if members["users"]:
                print(f"  Users: {', '.join(sorted(members['users']))}")
            if members["machines"]:
                print(f"  Machines: {', '.join(sorted(members['machines']))}")

    # Print summary statistics
    print("\n### Summary Statistics ###")
    total_vars = len(ownership)
    total_secrets = sum(1 for info in ownership.values() if info["type"] == "secret")
    total_values = sum(1 for info in ownership.values() if info["type"] == "value")

    print(f"Total variables: {total_vars}")
    print(f"  - Secrets: {total_secrets}")
    print(f"  - Values: {total_values}")

    # User statistics
    all_users = set()
    for info in ownership.values():
        all_users.update(info["users"])
    print(f"\nTotal users with access: {len(all_users)}")
    for user in sorted(all_users):
        user_count = sum(1 for info in ownership.values() if user in info["users"])
        print(f"  - {user}: {user_count} variables")

    # Machine statistics
    all_machines = set()
    for info in ownership.values():
        all_machines.update(info["machines"])
    print(f"\nTotal machines with access: {len(all_machines)}")
    for machine in sorted(all_machines):
        machine_count = sum(
            1 for info in ownership.values() if machine in info["machines"]
        )
        print(f"  - {machine}: {machine_count} variables")


def main() -> int | None:
    # Try to find the repository root
    # First, check if we're in a git repo and find the root
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
            print("Error: Could not find repository root with 'vars' directory")
            print("Please run this command from within the onix-core repository")
            sys.exit(1)

    vars_path = repo_root / "vars"
    groups_path = repo_root / "sops" / "groups"

    # Scan and analyze
    print("Scanning variables directory...")
    ownership = scan_vars_directory(vars_path)

    print("Analyzing groups...")
    groups = analyze_groups(groups_path)

    # Generate report
    print_ownership_report(ownership, groups)


if __name__ == "__main__":
    main()
