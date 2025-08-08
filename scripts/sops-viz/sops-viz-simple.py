#!/usr/bin/env python3
"""
Simple SOPS Hierarchy Visualizer - No external dependencies required
"""

import argparse
from collections import defaultdict
from pathlib import Path


class SimpleSOPSVisualizer:
    def __init__(self, sops_root):
        self.sops_root = Path(sops_root)
        self.users = set()
        self.machines = set()
        self.groups = defaultdict(lambda: {"users": set(), "machines": set()})
        self.secrets = defaultdict(lambda: {"users": set(), "machines": set()})

    def scan_structure(self):
        """Scan the SOPS directory structure"""
        # Scan users
        users_dir = self.sops_root / "users"
        if users_dir.exists():
            for user_dir in users_dir.iterdir():
                if user_dir.is_dir():
                    self.users.add(user_dir.name)

        # Scan machines
        machines_dir = self.sops_root / "machines"
        if machines_dir.exists():
            for machine_dir in machines_dir.iterdir():
                if machine_dir.is_dir():
                    self.machines.add(machine_dir.name)

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
                            self.groups[group_name]["users"].add(user_link.name)

                    # Check for machines
                    machines_subdir = group_dir / "machines"
                    if machines_subdir.exists():
                        for machine_link in machines_subdir.iterdir():
                            self.groups[group_name]["machines"].add(machine_link.name)

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

    def print_tree(self, name, items, prefix="", is_last=True):
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

    def display_hierarchy(self):
        """Display the full hierarchy"""
        print("\n🔐 SOPS ACCESS CONTROL HIERARCHY")
        print("=" * 50)

        # Users section
        if self.users:
            print("\n👥 USERS")
            print("─" * 20)
            for user in sorted(self.users):
                print(f"  • {user}")
                # Show groups
                user_groups = [
                    g for g, data in self.groups.items() if user in data["users"]
                ]
                if user_groups:
                    print(f"    └─ Groups: {', '.join(user_groups)}")
                # Show secrets
                user_secrets = [
                    s for s, data in self.secrets.items() if user in data["users"]
                ]
                if user_secrets:
                    print("    └─ Secrets:")
                    for secret in user_secrets:
                        print(f"        • {secret}")

        # Machines section
        if self.machines:
            print("\n🖥️  MACHINES")
            print("─" * 20)
            for machine in sorted(self.machines):
                print(f"  • {machine}")
                # Show groups
                machine_groups = [
                    g for g, data in self.groups.items() if machine in data["machines"]
                ]
                if machine_groups:
                    print(f"    └─ Groups: {', '.join(machine_groups)}")
                # Show secrets
                machine_secrets = [
                    s for s, data in self.secrets.items() if machine in data["machines"]
                ]
                if machine_secrets:
                    print("    └─ Secrets:")
                    for secret in machine_secrets:
                        print(f"        • {secret}")

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
                    print("    └─ Machines:")
                    for machine in sorted(self.groups[group]["machines"]):
                        print(f"        • {machine}")

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

                if access_list:
                    print("    └─ Access granted to:")
                    for i, entity in enumerate(access_list):
                        prefix = (
                            "        └─ "
                            if i == len(access_list) - 1
                            else "        ├─ "
                        )
                        print(f"{prefix}{entity}")

    def display_access_matrix(self):
        """Display access matrix as a table"""
        print("\n📊 SECRET ACCESS MATRIX")
        print("=" * 80)

        # Header
        print(f"{'Secret':<30} {'Users':<25} {'Machines':<25}")
        print("-" * 80)

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
            print(f"{secret:<30} {users:<25} {machines:<25}")

        print("-" * 80)

    def display_summary(self):
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

    def generate_dot_file(self, filename="sops_hierarchy.dot"):
        """Generate a Graphviz DOT file for external processing"""
        with open(filename, "w") as f:
            f.write("digraph SOPS_Hierarchy {\n")
            f.write("  rankdir=TB;\n")
            f.write("  node [shape=box, style=rounded];\n\n")

            # Define nodes
            f.write("  // Users\n")
            for user in sorted(self.users):
                f.write(
                    f'  "user_{user}" [label="{user}", style="rounded,filled", fillcolor="lightblue"];\n'
                )

            f.write("\n  // Machines\n")
            for machine in sorted(self.machines):
                f.write(
                    f'  "machine_{machine}" [label="{machine}", style="rounded,filled", fillcolor="lightyellow"];\n'
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


def main():
    parser = argparse.ArgumentParser(
        description="Simple SOPS Hierarchy Visualizer (no dependencies required)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                  # Show hierarchy tree
  %(prog)s --matrix        # Show access matrix
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
    if args.matrix or args.dot:
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

    if args.dot or args.all:
        dot_file = visualizer.generate_dot_file(args.dot_output)
        print(f"\n✓ DOT file generated: {dot_file}")
        print(
            f"  To create a graph image, run: dot -Tpng {dot_file} -o sops_hierarchy.png"
        )

    # Always show summary
    visualizer.display_summary()


if __name__ == "__main__":
    main()
