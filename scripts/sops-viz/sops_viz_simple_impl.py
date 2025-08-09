#!/usr/bin/env python3
"""
Simple SOPS Hierarchy Visualizer - No external dependencies required
"""

import argparse
import json
from collections import defaultdict
from pathlib import Path


class SimpleSOPSVisualizer:
    def __init__(self, sops_root: str | Path) -> None:
        self.sops_root = Path(sops_root)
        self.users = {}  # user -> {"keys": [...]}
        self.machines = {}  # machine -> {"keys": [...]}
        self.groups = defaultdict(lambda: {"users": set(), "machines": set()})
        self.secrets = defaultdict(
            lambda: {"users": set(), "machines": set(), "groups": set()}
        )

    def scan_structure(self) -> None:
        """Scan the SOPS directory structure"""
        # Scan users
        users_dir = self.sops_root / "users"
        if users_dir.exists():
            for user_dir in users_dir.iterdir():
                if user_dir.is_dir():
                    user_name = user_dir.name
                    self.users[user_name] = {"keys": []}
                    key_file = user_dir / "key.json"
                    if key_file.exists():
                        try:
                            with key_file.open() as f:
                                keys_data = json.load(f)
                                age_keys = [
                                    k["publickey"]
                                    for k in keys_data
                                    if k.get("type") == "age"
                                ]
                                self.users[user_name]["keys"] = age_keys
                        except (json.JSONDecodeError, KeyError):
                            pass

        # Scan machines
        machines_dir = self.sops_root / "machines"
        if machines_dir.exists():
            for machine_dir in machines_dir.iterdir():
                if machine_dir.is_dir():
                    machine_name = machine_dir.name
                    self.machines[machine_name] = {"keys": []}
                    key_file = machine_dir / "key.json"
                    if key_file.exists():
                        try:
                            with key_file.open() as f:
                                keys_data = json.load(f)
                                age_keys = [
                                    k["publickey"]
                                    for k in keys_data
                                    if k.get("type") == "age"
                                ]
                                self.machines[machine_name]["keys"] = age_keys
                        except (json.JSONDecodeError, KeyError):
                            pass

        # Scan groups
        groups_dir = self.sops_root / "groups"
        if groups_dir.exists():
            for group_dir in groups_dir.iterdir():
                if group_dir.is_dir():
                    group_name = group_dir.name

                    # Check for users
                    users_subdir = group_dir / "users"
                    if users_subdir.exists():
                        for user_link in users_subdir.iterdir():
                            if user_link.name in self.users:
                                self.groups[group_name]["users"].add(user_link.name)

                    # Check for machines
                    machines_subdir = group_dir / "machines"
                    if machines_subdir.exists():
                        for machine_link in machines_subdir.iterdir():
                            if machine_link.name in self.machines:
                                self.groups[group_name]["machines"].add(
                                    machine_link.name
                                )

        # Scan secrets
        secrets_dir = self.sops_root / "secrets"
        if secrets_dir.exists():
            for secret_dir in secrets_dir.iterdir():
                if secret_dir.is_dir():
                    secret_name = secret_dir.name

                    # Check for user access
                    users_subdir = secret_dir / "users"
                    if users_subdir.exists():
                        for user_link in users_subdir.iterdir():
                            self.secrets[secret_name]["users"].add(user_link.name)

                    # Check for machine access
                    machines_subdir = secret_dir / "machines"
                    if machines_subdir.exists():
                        for machine_link in machines_subdir.iterdir():
                            self.secrets[secret_name]["machines"].add(machine_link.name)

                    # Check for group access
                    groups_subdir = secret_dir / "groups"
                    if groups_subdir.exists():
                        for group_link in groups_subdir.iterdir():
                            self.secrets[secret_name]["groups"].add(group_link.name)

    def print_tree(
        self, name: str, items: list, prefix: str = "", is_last: bool = True
    ) -> None:
        """Print a tree structure"""
        connector = "└── " if is_last else "├── "
        print(prefix + connector + name)

        if isinstance(items, dict):
            items = list(items.items())
        elif not isinstance(items, list):
            items = list(items)

        extension = "    " if is_last else "│   "

        for i, item in enumerate(items):
            is_last_item = i == len(items) - 1
            if isinstance(item, tuple):
                key, value = item
                self.print_tree(key, value, prefix + extension, is_last_item)
            else:
                self.print_tree(str(item), [], prefix + extension, is_last_item)

    def get_inherited_secrets(self, entity_name: str, entity_type: str) -> dict:
        """Get secrets that an entity inherits through group membership

        Args:
            entity_name: Name of the user or machine
            entity_type: Either 'users' or 'machines'

        Returns:
            Dict mapping secret names to list of groups they're inherited from
        """
        inherited_secrets = {}

        # Find groups this entity belongs to
        entity_groups = [
            group
            for group, data in self.groups.items()
            if entity_name in data[entity_type]
        ]

        # Find secrets accessible through those groups
        for secret, data in self.secrets.items():
            groups_with_access = []
            for group in entity_groups:
                if group in data["groups"]:
                    groups_with_access.append(group)
            if groups_with_access:
                inherited_secrets[secret] = groups_with_access

        return inherited_secrets

    def display_hierarchy(self) -> None:
        """Display the full hierarchy"""
        print("\n🔐 SOPS ACCESS CONTROL HIERARCHY")
        print("=" * 50)

        # Users section
        if self.users:
            print("\n👥 USERS")
            print("─" * 20)
            for user in sorted(self.users.keys()):
                print(f"  • {user}")
                # Show age public keys
                if self.users[user]["keys"]:
                    print("    ├─ Age public keys:")
                    for key in self.users[user]["keys"]:
                        print(f"    │   • {key}")
                # Show groups
                user_groups = [
                    g for g, data in self.groups.items() if user in data["users"]
                ]
                if user_groups:
                    print(f"    ├─ Groups: {', '.join(user_groups)}")
                # Show secrets (both direct and inherited)
                direct_secrets = [
                    s for s, data in self.secrets.items() if user in data["users"]
                ]
                inherited_secrets = self.get_inherited_secrets(user, "users")

                all_secrets = set(direct_secrets) | set(inherited_secrets.keys())
                if all_secrets:
                    print("    └─ Secrets:")
                    for secret in sorted(all_secrets):
                        if secret in direct_secrets and secret in inherited_secrets:
                            groups = ", ".join(inherited_secrets[secret])
                            print(f"        • {secret} (direct + via {groups})")
                        elif secret in direct_secrets:
                            print(f"        • {secret} (direct)")
                        else:
                            groups = ", ".join(inherited_secrets[secret])
                            print(f"        • {secret} (via {groups})")

        # Machines section
        if self.machines:
            print("\n🖥️  MACHINES")
            print("─" * 20)
            for machine in sorted(self.machines.keys()):
                print(f"  • {machine}")
                # Show age public keys
                if self.machines[machine]["keys"]:
                    print("    ├─ Age public keys:")
                    for key in self.machines[machine]["keys"]:
                        print(f"    │   • {key}")
                # Show groups
                machine_groups = [
                    g for g, data in self.groups.items() if machine in data["machines"]
                ]
                if machine_groups:
                    print(f"    ├─ Groups: {', '.join(machine_groups)}")
                # Show secrets (both direct and inherited)
                direct_secrets = [
                    s for s, data in self.secrets.items() if machine in data["machines"]
                ]
                inherited_secrets = self.get_inherited_secrets(machine, "machines")

                all_secrets = set(direct_secrets) | set(inherited_secrets.keys())
                if all_secrets:
                    print("    └─ Secrets:")
                    for secret in sorted(all_secrets):
                        if secret in direct_secrets and secret in inherited_secrets:
                            groups = ", ".join(inherited_secrets[secret])
                            print(f"        • {secret} (direct + via {groups})")
                        elif secret in direct_secrets:
                            print(f"        • {secret} (direct)")
                        else:
                            groups = ", ".join(inherited_secrets[secret])
                            print(f"        • {secret} (via {groups})")

        # Groups section
        if self.groups:
            print("\n🏢 GROUPS")
            print("─" * 20)
            for group in sorted(self.groups.keys()):
                print(f"  • {group}")
                if self.groups[group]["users"]:
                    print("    ├─ Users:")
                    for user in sorted(self.groups[group]["users"]):
                        print(f"    │   • {user}")
                if self.groups[group]["machines"]:
                    prefix = (
                        "    ├─"
                        if any(
                            s
                            for s, data in self.secrets.items()
                            if group in data["groups"]
                        )
                        else "    └─"
                    )
                    print(f"{prefix} Machines:")
                    for machine in sorted(self.groups[group]["machines"]):
                        print(f"        • {machine}")
                # Show secrets this group has access to
                group_secrets = [
                    s for s, data in self.secrets.items() if group in data["groups"]
                ]
                if group_secrets:
                    print("    └─ Secrets:")
                    for secret in sorted(group_secrets):
                        print(f"        • {secret}")

        # Secrets section
        if self.secrets:
            print("\n🔒 SECRETS")
            print("─" * 20)
            for secret in sorted(self.secrets.keys()):
                print(f"  • {secret}")
                access_list = []
                if self.secrets[secret]["users"]:
                    access_list.extend(
                        [f"User: {u}" for u in sorted(self.secrets[secret]["users"])]
                    )
                if self.secrets[secret]["machines"]:
                    access_list.extend(
                        [
                            f"Machine: {m}"
                            for m in sorted(self.secrets[secret]["machines"])
                        ]
                    )
                if self.secrets[secret]["groups"]:
                    access_list.extend(
                        [f"Group: {g}" for g in sorted(self.secrets[secret]["groups"])]
                    )

                if access_list:
                    print("    └─ Access granted to:")
                    for i, entity in enumerate(access_list):
                        prefix = (
                            "        └─ "
                            if i == len(access_list) - 1
                            else "        ├─ "
                        )
                        print(f"{prefix}{entity}")

    def display_access_matrix(self) -> None:
        """Display access matrix as a table"""
        print("\n📊 SECRET ACCESS MATRIX")
        print("=" * 100)

        # Header
        print(f"{'Secret':<30} {'Users':<25} {'Machines':<25} {'Groups':<20}")
        print("-" * 100)

        # Rows
        for secret in sorted(self.secrets.keys()):
            users = (
                ", ".join(sorted(self.secrets[secret]["users"]))
                if self.secrets[secret]["users"]
                else "-"
            )
            machines = (
                ", ".join(sorted(self.secrets[secret]["machines"]))
                if self.secrets[secret]["machines"]
                else "-"
            )
            groups = (
                ", ".join(sorted(self.secrets[secret]["groups"]))
                if self.secrets[secret]["groups"]
                else "-"
            )
            print(f"{secret:<30} {users:<25} {machines:<25} {groups:<20}")

        print("-" * 100)

    def display_keys_table(self) -> None:
        """Display all age public keys in a table"""
        print("\n🔑 AGE PUBLIC KEYS")
        print("=" * 80)

        # Header
        print(f"{'Entity':<20} {'Type':<10} {'Age Public Key'}")
        print("-" * 80)

        # Users
        for user in sorted(self.users.keys()):
            if self.users[user]["keys"]:
                for i, key in enumerate(self.users[user]["keys"]):
                    if i == 0:
                        print(f"{user:<20} {'User':<10} {key}")
                    else:
                        print(f"{'':<20} {'':<10} {key}")

        # Machines
        for machine in sorted(self.machines.keys()):
            if self.machines[machine]["keys"]:
                for i, key in enumerate(self.machines[machine]["keys"]):
                    if i == 0:
                        print(f"{machine:<20} {'Machine':<10} {key}")
                    else:
                        print(f"{'':<20} {'':<10} {key}")

        print("-" * 80)

    def display_summary(self) -> None:
        """Display summary statistics"""
        print("\n📈 SUMMARY STATISTICS")
        print("=" * 30)
        print(f"  Total Users:    {len(self.users)}")
        print(f"  Total Machines: {len(self.machines)}")
        print(f"  Total Groups:   {len(self.groups)}")
        print(f"  Total Secrets:  {len(self.secrets)}")

        # Calculate access statistics
        total_user_access = sum(len(data["users"]) for data in self.secrets.values())
        total_machine_access = sum(
            len(data["machines"]) for data in self.secrets.values()
        )

        print(f"\n  User Access Grants:    {total_user_access}")
        print(f"  Machine Access Grants: {total_machine_access}")

    def generate_dot_file(self, filename: str = "sops_hierarchy.dot") -> str:
        """Generate a Graphviz DOT file for external processing"""
        with Path(filename).open("w") as f:
            f.write("digraph SOPS_Hierarchy {\n")
            f.write("  rankdir=TB;\n")
            f.write("  node [shape=box, style=rounded];\n\n")

            # Define nodes
            f.write("  // Users\n")
            for user in sorted(self.users.keys()):
                label = user
                if self.users[user]["keys"]:
                    # Show first 8 chars of first key for brevity
                    key_preview = self.users[user]["keys"][0][:8] + "..."
                    label = f"{user}\n[{key_preview}]"
                f.write(
                    f'  "user_{user}" [label="{label}", style="rounded,filled", fillcolor="lightblue"];\n'
                )

            f.write("\n  // Machines\n")
            for machine in sorted(self.machines.keys()):
                label = machine
                if self.machines[machine]["keys"]:
                    # Show first 8 chars of first key for brevity
                    key_preview = self.machines[machine]["keys"][0][:8] + "..."
                    label = f"{machine}\n[{key_preview}]"
                f.write(
                    f'  "machine_{machine}" [label="{label}", style="rounded,filled", fillcolor="lightyellow"];\n'
                )

            f.write("\n  // Groups\n")
            for group in sorted(self.groups.keys()):
                f.write(
                    f'  "group_{group}" [label="{group}", shape="diamond", style="filled", fillcolor="lightgreen"];\n'
                )

            f.write("\n  // Secrets\n")
            for secret in sorted(self.secrets.keys()):
                f.write(
                    f'  "secret_{secret}" [label="{secret}", shape="cylinder", style="filled", fillcolor="lightcoral"];\n'
                )

            # Define relationships
            f.write("\n  // Group memberships\n")
            for group, data in self.groups.items():
                for user in data["users"]:
                    f.write(
                        f'  "user_{user}" -> "group_{group}" [label="member", color="blue"];\n'
                    )
                for machine in data["machines"]:
                    f.write(
                        f'  "machine_{machine}" -> "group_{group}" [label="member", color="orange"];\n'
                    )

            f.write("\n  // Secret access\n")
            for secret, data in self.secrets.items():
                for user in data["users"]:
                    f.write(
                        f'  "user_{user}" -> "secret_{secret}" [label="access", color="green", style="dashed"];\n'
                    )
                for machine in data["machines"]:
                    f.write(
                        f'  "machine_{machine}" -> "secret_{secret}" [label="access", color="purple", style="dashed"];\n'
                    )

            f.write("}\n")

        return filename


def main() -> int | None:
    parser = argparse.ArgumentParser(
        description="Simple SOPS Hierarchy Visualizer (no dependencies required)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                  # Show hierarchy tree
  %(prog)s --matrix        # Show access matrix
  %(prog)s --keys          # Show age public keys
  %(prog)s --dot           # Generate DOT file for Graphviz
  %(prog)s --all           # Show all visualizations
        """,
    )
    parser.add_argument(
        "--sops-root", default="./sops", help="Path to SOPS root directory"
    )
    parser.add_argument(
        "--matrix", action="store_true", help="Show access matrix table"
    )
    parser.add_argument(
        "--keys", action="store_true", help="Show age public keys table"
    )
    parser.add_argument("--dot", action="store_true", help="Generate Graphviz DOT file")
    parser.add_argument(
        "--dot-output",
        default="sops_hierarchy.dot",
        help="Output filename for DOT file",
    )
    parser.add_argument("--all", action="store_true", help="Show all visualizations")

    args = parser.parse_args()

    # Default to tree view if nothing specified
    show_tree = True
    if args.matrix or args.keys or args.dot:
        show_tree = args.all

    # Initialize and scan
    visualizer = SimpleSOPSVisualizer(args.sops_root)

    if not Path(args.sops_root).exists():
        print(f"Error: SOPS directory not found at {args.sops_root}")
        return 1

    print("Scanning SOPS structure...")
    visualizer.scan_structure()

    # Display visualizations
    if show_tree:
        visualizer.display_hierarchy()

    if args.matrix or args.all:
        visualizer.display_access_matrix()

    if args.keys or args.all:
        visualizer.display_keys_table()

    if args.dot or args.all:
        dot_file = visualizer.generate_dot_file(args.dot_output)
        print(f"\n✓ DOT file generated: {dot_file}")
        print(
            f"  To create a graph image, run: dot -Tpng {dot_file} -o sops_hierarchy.png"
        )

    # Always show summary
    visualizer.display_summary()
    return None


if __name__ == "__main__":
    main()
