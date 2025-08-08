#!/usr/bin/env python3
"""
Analyze machine configurations in the onix-core repository.
Shows machine details, tags, deployment targets, and relationships.
"""

import re
import sys
from collections import defaultdict
from pathlib import Path


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

    # Parse each machine block
    machine_pattern = r"(\w+)\s*=\s*{([^}]+)};"
    for match in re.finditer(machine_pattern, machines_content, re.DOTALL):
        machine_name = match.group(1)
        machine_content = match.group(2)

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

        # Extract deploy info
        deploy_match = re.search(r"deploy\s*=\s*{([^}]+)};", machine_content, re.DOTALL)
        if deploy_match:
            deploy_content = deploy_match.group(1)

            target_match = re.search(r'targetHost\s*=\s*"([^"]+)"', deploy_content)
            if target_match:
                machine_info["deploy"]["targetHost"] = target_match.group(1)

            build_match = re.search(r'buildHost\s*=\s*"([^"]+)"', deploy_content)
            if build_match:
                machine_info["deploy"]["buildHost"] = build_match.group(1)

        machines[machine_name] = machine_info

    return machines


def analyze_tags(machines: dict[str, dict]) -> dict[str, list[str]]:
    """Analyze tags across all machines."""
    tag_machines = defaultdict(list)

    for machine_name, info in machines.items():
        for tag in info["tags"]:
            tag_machines[tag].append(machine_name)

    return dict(tag_machines)


def print_machines_report(
    machines: dict[str, dict], tag_machines: dict[str, list[str]]
) -> None:
    """Print a formatted machines report."""
    print("Machine Configuration Report")
    print("=" * 80)

    # Print machine details
    print("\n### Machine Details ###")
    for machine_name in sorted(machines.keys()):
        info = machines[machine_name]
        print(f"\n{machine_name}:")
        print(f"  Target: {info['deploy']['targetHost']}")
        if info["deploy"]["buildHost"]:
            print(f"  Build Host: {info['deploy']['buildHost']}")
        if info["tags"]:
            print(f"  Tags: {', '.join(sorted(info['tags']))}")
        else:
            print("  Tags: (none)")

    # Print tag analysis
    print("\n### Tag Analysis ###")

    # Group tags by category
    tailnet_tags = {k: v for k, v in tag_machines.items() if k.startswith("tailnet-")}
    hardware_tags = {
        k: v
        for k, v in tag_machines.items()
        if k in ["laptop", "desktop", "wsl", "nvidia"]
    }
    ui_tags = {k: v for k, v in tag_machines.items() if k in ["hyprland"]}
    service_tags = {
        k: v
        for k, v in tag_machines.items()
        if "server" in k
        or k
        in [
            "prometheus",
            "monitoring",
            "log-collector",
            "nix-cache",
            "onix-cache",
            "wiki-js",
        ]
    }
    other_tags = {
        k: v
        for k, v in tag_machines.items()
        if k not in tailnet_tags
        and k not in hardware_tags
        and k not in ui_tags
        and k not in service_tags
    }

    if tailnet_tags:
        print("\nTailnet Tags:")
        for tag in sorted(tailnet_tags.keys()):
            print(f"  {tag}: {', '.join(sorted(tailnet_tags[tag]))}")

    if hardware_tags:
        print("\nHardware Tags:")
        for tag in sorted(hardware_tags.keys()):
            print(f"  {tag}: {', '.join(sorted(hardware_tags[tag]))}")

    if ui_tags:
        print("\nUI Tags:")
        for tag in sorted(ui_tags.keys()):
            print(f"  {tag}: {', '.join(sorted(ui_tags[tag]))}")

    if service_tags:
        print("\nService Tags:")
        for tag in sorted(service_tags.keys()):
            print(f"  {tag}: {', '.join(sorted(service_tags[tag]))}")

    if other_tags:
        print("\nOther Tags:")
        for tag in sorted(other_tags.keys()):
            print(f"  {tag}: {', '.join(sorted(other_tags[tag]))}")

    # Print deployment target analysis
    print("\n### Deployment Target Analysis ###")

    # Group by target type
    ip_targets = []
    hostname_targets = []

    for machine_name, info in machines.items():
        target = info["deploy"]["targetHost"]
        if target:
            # Remove 'root@' prefix
            target_clean = target.replace("root@", "")

            # Check if it's an IP address
            if re.match(r"^\d+\.\d+\.\d+\.\d+$", target_clean):
                ip_targets.append((machine_name, target_clean))
            else:
                hostname_targets.append((machine_name, target_clean))

    if hostname_targets:
        print("\nHostname-based Targets:")
        for machine, target in sorted(hostname_targets):
            print(f"  {machine}: {target}")

    if ip_targets:
        print("\nIP-based Targets:")
        for machine, target in sorted(ip_targets):
            print(f"  {machine}: {target}")

    # Print summary statistics
    print("\n### Summary Statistics ###")
    print(f"Total machines: {len(machines)}")
    print(f"Total unique tags: {len(tag_machines)}")

    # Count machines by owner (based on machine prefix)
    owner_counts = defaultdict(int)
    for machine_name in machines:
        if "-" in machine_name:
            owner = machine_name.split("-")[0]
            owner_counts[owner] += 1
        else:
            owner_counts["other"] += 1

    print("\nMachines by owner prefix:")
    for owner in sorted(owner_counts.keys()):
        print(f"  {owner}: {owner_counts[owner]} machines")

    # Tag frequency
    print("\nMost common tags:")
    tag_freq = [(tag, len(machines)) for tag, machines in tag_machines.items()]
    tag_freq.sort(key=lambda x: x[1], reverse=True)
    for tag, count in tag_freq[:10]:
        print(f"  {tag}: {count} machines")


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
            print("Error: Could not find inventory/core/machines.nix")
            print("Please run this command from within the onix-core repository")
            sys.exit(1)

    machines_path = repo_root / "inventory" / "core" / "machines.nix"

    # Parse and analyze
    print("Parsing machines.nix...")
    machines = parse_machines_nix(machines_path)

    print("Analyzing tags...")
    tag_machines = analyze_tags(machines)

    # Generate report
    print_machines_report(machines, tag_machines)


if __name__ == "__main__":
    main()
