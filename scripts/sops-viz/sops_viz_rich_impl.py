#!/usr/bin/env python3
"""
SOPS Access Control Hierarchy Visualizer

This script analyzes the SOPS directory structure and visualizes the relationships
between users, groups, machines, and secrets using Rich (TUI) or Graphviz.
"""

import argparse
import json
from collections import defaultdict
from pathlib import Path

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.tree import Tree

try:
    import graphviz

    HAS_GRAPHVIZ = True
except ImportError:
    HAS_GRAPHVIZ = False


class SOPSHierarchyAnalyzer:
    def __init__(self, sops_root: Path) -> None:
        self.sops_root = Path(sops_root)
        self.users = {}  # user -> {"keys": [...]}
        self.machines = {}  # machine -> {"keys": [...]}
        self.groups = defaultdict(lambda: {"users": set(), "machines": set()})
        self.secrets = defaultdict(
            lambda: {
                "users": set(),
                "machines": set(),
                "groups": set(),
                "age_recipients": [],
            }
        )

    def scan_structure(self) -> None:
        """Scan the SOPS directory structure and build relationships"""
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

                    # Check for users in group
                    users_subdir = group_dir / "users"
                    if users_subdir.exists():
                        for user_link in users_subdir.iterdir():
                            if user_link.name in self.users:
                                self.groups[group_name]["users"].add(user_link.name)

                    # Check for machines in group
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

                    # Check for secret file
                    secret_file = secret_dir / "secret"
                    if secret_file.exists():
                        # In real implementation, we'd parse age recipients
                        pass

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

    def create_rich_tree(self) -> Tree:
        """Create a Rich tree visualization of the hierarchy"""
        # Create root
        tree = Tree("🔐 [bold blue]SOPS Access Control Hierarchy[/bold blue]")

        # Add users section
        if self.users:
            users_branch = tree.add("👥 [bold green]Users[/bold green]")
            for user in sorted(self.users.keys()):
                user_node = users_branch.add(f"[cyan]{user}[/cyan]")
                # Show age public keys
                if self.users[user]["keys"]:
                    keys_node = user_node.add("[dim]Age public keys:[/dim]")
                    for key in self.users[user]["keys"]:
                        keys_node.add(f"[dim italic]{key}[/dim italic]")
                # Show which groups the user belongs to
                user_groups = [
                    g for g, data in self.groups.items() if user in data["users"]
                ]
                if user_groups:
                    groups_text = ", ".join(user_groups)
                    user_node.add(f"[dim]Groups: {groups_text}[/dim]")
                # Show which secrets the user has access to (both direct and inherited)
                direct_secrets = [
                    s for s, data in self.secrets.items() if user in data["users"]
                ]
                inherited_secrets = self.get_inherited_secrets(user, "users")

                all_secrets = set(direct_secrets) | set(inherited_secrets.keys())
                if all_secrets:
                    for secret in sorted(all_secrets):
                        access_info = []
                        if secret in direct_secrets:
                            access_info.append("[red]direct[/red]")
                        if secret in inherited_secrets:
                            for group in inherited_secrets[secret]:
                                access_info.append(f"[yellow]{group}[/yellow]")
                        user_node.add(
                            f"🔓 [bold]{secret}[/bold] ({', '.join(access_info)})"
                        )

        # Add machines section
        if self.machines:
            machines_branch = tree.add("🖥️  [bold yellow]Machines[/bold yellow]")
            for machine in sorted(self.machines.keys()):
                machine_node = machines_branch.add(f"[magenta]{machine}[/magenta]")
                # Show age public keys
                if self.machines[machine]["keys"]:
                    keys_node = machine_node.add("[dim]Age public keys:[/dim]")
                    for key in self.machines[machine]["keys"]:
                        keys_node.add(f"[dim italic]{key}[/dim italic]")
                # Show which groups the machine belongs to
                machine_groups = [
                    g for g, data in self.groups.items() if machine in data["machines"]
                ]
                if machine_groups:
                    groups_text = ", ".join(machine_groups)
                    machine_node.add(f"[dim]Groups: {groups_text}[/dim]")
                # Show which secrets the machine has access to (both direct and inherited)
                direct_secrets = [
                    s for s, data in self.secrets.items() if machine in data["machines"]
                ]
                inherited_secrets = self.get_inherited_secrets(machine, "machines")

                all_secrets = set(direct_secrets) | set(inherited_secrets.keys())
                if all_secrets:
                    for secret in sorted(all_secrets):
                        access_info = []
                        if secret in direct_secrets:
                            access_info.append("[red]direct[/red]")
                        if secret in inherited_secrets:
                            for group in inherited_secrets[secret]:
                                access_info.append(f"[yellow]{group}[/yellow]")
                        machine_node.add(
                            f"🔓 [bold]{secret}[/bold] ({', '.join(access_info)})"
                        )

        # Add groups section
        if self.groups:
            groups_branch = tree.add("🏢 [bold cyan]Groups[/bold cyan]")
            for group in sorted(self.groups.keys()):
                group_node = groups_branch.add(f"[blue]{group}[/blue]")

                # Add users in group
                if self.groups[group]["users"]:
                    users_sub = group_node.add("[dim]Users:[/dim]")
                    for user in sorted(self.groups[group]["users"]):
                        users_sub.add(f"👤 [cyan]{user}[/cyan]")

                # Add machines in group
                if self.groups[group]["machines"]:
                    machines_sub = group_node.add("[dim]Machines:[/dim]")
                    for machine in sorted(self.groups[group]["machines"]):
                        machines_sub.add(f"🖥️  [magenta]{machine}[/magenta]")

                # Add secrets the group has access to
                group_secrets = [
                    s for s, data in self.secrets.items() if group in data["groups"]
                ]
                if group_secrets:
                    secrets_sub = group_node.add("[dim]Secrets:[/dim]")
                    for secret in sorted(group_secrets):
                        secrets_sub.add(f"🔓 [yellow]{secret}[/yellow]")

        # Add secrets section
        if self.secrets:
            secrets_branch = tree.add("🔒 [bold red]Secrets[/bold red]")
            for secret in sorted(self.secrets.keys()):
                secret_node = secrets_branch.add(f"[red]{secret}[/red]")

                # Show who has access
                access_list = []
                if self.secrets[secret]["users"]:
                    for user in sorted(self.secrets[secret]["users"]):
                        access_list.append(f"👤 [cyan]{user}[/cyan]")
                if self.secrets[secret]["machines"]:
                    for machine in sorted(self.secrets[secret]["machines"]):
                        access_list.append(f"🖥️  [magenta]{machine}[/magenta]")
                if self.secrets[secret]["groups"]:
                    for group in sorted(self.secrets[secret]["groups"]):
                        access_list.append(f"🏢 [blue]{group}[/blue]")

                if access_list:
                    access_node = secret_node.add("[dim]Access granted to:[/dim]")
                    for entity in access_list:
                        access_node.add(entity)

        return tree

    def create_access_matrix_table(self) -> Table:
        """Create an access matrix table showing secret access"""
        table = Table(
            title="Secret Access Matrix", show_header=True, header_style="bold magenta"
        )
        table.add_column("Secret", style="red", no_wrap=True)
        table.add_column("Users", style="cyan")
        table.add_column("Machines", style="magenta")
        table.add_column("Groups", style="blue")

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
            table.add_row(secret, users, machines, groups)

        return table

    def create_key_table(self) -> Table:
        """Create a table showing all age public keys"""
        table = Table(
            title="Age Public Keys", show_header=True, header_style="bold blue"
        )
        table.add_column("Entity", style="green", no_wrap=True)
        table.add_column("Type", style="yellow")
        table.add_column("Age Public Key(s)", style="cyan")

        # Add users
        for user in sorted(self.users.keys()):
            if self.users[user]["keys"]:
                keys_str = "\n".join(self.users[user]["keys"])
                table.add_row(user, "User", keys_str)

        # Add machines
        for machine in sorted(self.machines.keys()):
            if self.machines[machine]["keys"]:
                keys_str = "\n".join(self.machines[machine]["keys"])
                table.add_row(machine, "Machine", keys_str)

        return table

    def create_graphviz_graph(
        self, output_format: str = "png", filename: str = "sops_hierarchy"
    ) -> str:
        """Create a Graphviz graph visualization"""
        if not HAS_GRAPHVIZ:
            msg = "graphviz package is not installed. Run: pip install graphviz"
            raise ImportError(msg)

        dot = graphviz.Digraph(comment="SOPS Access Control Hierarchy")
        dot.attr(rankdir="TB")
        dot.attr("node", fontname="Arial")

        # Style settings
        dot.attr("node", shape="box", style="rounded,filled")

        # Create subgraphs for better organization
        with dot.subgraph(name="cluster_users") as c:
            c.attr(label="Users", style="filled", color="lightgrey")
            for user in sorted(self.users.keys()):
                label = user
                if self.users[user]["keys"]:
                    # Show first 8 chars of first key for brevity
                    key_preview = self.users[user]["keys"][0][:8] + "..."
                    label = f"{user}\n[{key_preview}]"
                c.node(f"user_{user}", label, fillcolor="lightblue", shape="ellipse")

        with dot.subgraph(name="cluster_machines") as c:
            c.attr(label="Machines", style="filled", color="lightgrey")
            for machine in sorted(self.machines.keys()):
                label = machine
                if self.machines[machine]["keys"]:
                    # Show first 8 chars of first key for brevity
                    key_preview = self.machines[machine]["keys"][0][:8] + "..."
                    label = f"{machine}\n[{key_preview}]"
                c.node(
                    f"machine_{machine}", label, fillcolor="lightyellow", shape="box"
                )

        with dot.subgraph(name="cluster_groups") as c:
            c.attr(label="Groups", style="filled", color="lightgrey")
            for group in sorted(self.groups.keys()):
                c.node(f"group_{group}", group, fillcolor="lightgreen", shape="diamond")

        with dot.subgraph(name="cluster_secrets") as c:
            c.attr(label="Secrets", style="filled", color="lightgrey")
            for secret in sorted(self.secrets.keys()):
                c.node(
                    f"secret_{secret}", secret, fillcolor="lightcoral", shape="cylinder"
                )

        # Add edges for group memberships
        for group, data in self.groups.items():
            for user in data["users"]:
                dot.edge(f"user_{user}", f"group_{group}", label="member", color="blue")
            for machine in data["machines"]:
                dot.edge(
                    f"machine_{machine}",
                    f"group_{group}",
                    label="member",
                    color="orange",
                )

        # Add edges for secret access
        for secret, data in self.secrets.items():
            for user in data["users"]:
                dot.edge(
                    f"user_{user}",
                    f"secret_{secret}",
                    label="access",
                    color="green",
                    style="dashed",
                )
            for machine in data["machines"]:
                dot.edge(
                    f"machine_{machine}",
                    f"secret_{secret}",
                    label="access",
                    color="purple",
                    style="dashed",
                )

        # Render the graph
        dot.render(filename, format=output_format, cleanup=True)
        return filename + "." + output_format


def main() -> int | None:
    parser = argparse.ArgumentParser(
        description="Visualize SOPS access control hierarchy",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                     # Show tree view in terminal
  %(prog)s --table            # Show access matrix table
  %(prog)s --keys             # Show age public keys table
  %(prog)s --graph            # Generate graph visualization (requires graphviz)
  %(prog)s --all              # Show all visualizations
        """,
    )
    parser.add_argument(
        "--sops-root", default="./sops", help="Path to SOPS root directory"
    )
    parser.add_argument("--table", action="store_true", help="Show access matrix table")
    parser.add_argument(
        "--keys", action="store_true", help="Show age public keys table"
    )
    parser.add_argument(
        "--graph",
        action="store_true",
        help="Generate Graphviz graph (requires graphviz package)",
    )
    parser.add_argument(
        "--graph-format",
        default="png",
        choices=["png", "svg", "pdf", "dot"],
        help="Output format for graph",
    )
    parser.add_argument(
        "--graph-output",
        default="sops_hierarchy",
        help="Output filename for graph (without extension)",
    )
    parser.add_argument(
        "--all", action="store_true", help="Show all visualization types"
    )

    args = parser.parse_args()

    # If no specific visualization is requested, default to tree
    if not any([args.table, args.keys, args.graph, args.all]):
        args.tree = True
    else:
        args.tree = args.all
        args.table = args.table or args.all
        args.keys = args.keys or args.all
        args.graph = args.graph or args.all

    # Initialize analyzer
    analyzer = SOPSHierarchyAnalyzer(args.sops_root)

    # Check if SOPS directory exists
    if not Path(args.sops_root).exists():
        console = Console()
        console.print(f"[red]Error: SOPS directory not found at {args.sops_root}[/red]")
        return 1

    # Scan the structure
    console = Console()
    with console.status("[bold green]Scanning SOPS structure..."):
        analyzer.scan_structure()

    # Show tree visualization
    if getattr(args, "tree", True):
        tree = analyzer.create_rich_tree()
        console.print(Panel(tree, title="SOPS Hierarchy Tree", border_style="blue"))
        console.print()

    # Show access matrix table
    if args.table:
        table = analyzer.create_access_matrix_table()
        console.print(table)
        console.print()

    # Show keys table
    if args.keys:
        key_table = analyzer.create_key_table()
        console.print(key_table)
        console.print()

    # Generate graph
    if args.graph:
        if not HAS_GRAPHVIZ:
            console.print(
                "[yellow]Warning: graphviz package not installed. Install with: pip install graphviz[/yellow]"
            )
        else:
            try:
                output_file = analyzer.create_graphviz_graph(
                    output_format=args.graph_format, filename=args.graph_output
                )
                console.print(f"[green]✓ Graph saved to: {output_file}[/green]")
            except Exception as e:
                console.print(f"[red]Error generating graph: {e}[/red]")

    # Show summary statistics
    stats = Text()
    stats.append("\n📊 ", style="bold")
    stats.append("Summary Statistics\n", style="bold underline")
    stats.append(f"  Users: {len(analyzer.users)}\n")
    stats.append(f"  Machines: {len(analyzer.machines)}\n")
    stats.append(f"  Groups: {len(analyzer.groups)}\n")
    stats.append(f"  Secrets: {len(analyzer.secrets)}\n")
    console.print(Panel(stats, border_style="dim"))
    return None


if __name__ == "__main__":
    main()
