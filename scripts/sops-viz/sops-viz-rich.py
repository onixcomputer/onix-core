#!/usr/bin/env python3
"""
SOPS Access Control Hierarchy Visualizer

This script analyzes the SOPS directory structure and visualizes the relationships
between users, groups, machines, and secrets using Rich (TUI) or Graphviz.
"""

import argparse
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
    def __init__(self, sops_root: Path):
        self.sops_root = Path(sops_root)
        self.users = {}  # user -> {keys: [...]}
        self.machines = {}  # machine -> {key: ...}
        self.groups = defaultdict(lambda: {"users": set(), "machines": set()})
        self.secrets = defaultdict(
            lambda: {"users": set(), "machines": set(), "age_recipients": []}
        )

    def scan_structure(self):
        """Scan the SOPS directory structure and build relationships"""
        # Scan users
        users_dir = self.sops_root / "users"
        if users_dir.exists():
            for user_dir in users_dir.iterdir():
                if user_dir.is_dir():
                    user_name = user_dir.name
                    key_file = user_dir / "key.json"
                    if key_file.exists():
                        # In real implementation, we'd parse the JSON to get age keys
                        self.users[user_name] = {"keys": []}

        # Scan machines
        machines_dir = self.sops_root / "machines"
        if machines_dir.exists():
            for machine_dir in machines_dir.iterdir():
                if machine_dir.is_dir():
                    machine_name = machine_dir.name
                    key_file = machine_dir / "key.json"
                    if key_file.exists():
                        self.machines[machine_name] = {"key": None}

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

                    # Check for secret file
                    secret_file = secret_dir / "secret"
                    if secret_file.exists():
                        # In real implementation, we'd parse age recipients
                        pass

    def create_rich_tree(self) -> Tree:
        """Create a Rich tree visualization of the hierarchy"""
        # Create root
        tree = Tree("🔐 [bold blue]SOPS Access Control Hierarchy[/bold blue]")

        # Add users section
        if self.users:
            users_branch = tree.add("👥 [bold green]Users[/bold green]")
            for user in sorted(self.users.keys()):
                user_node = users_branch.add(f"[cyan]{user}[/cyan]")
                # Show which groups the user belongs to
                user_groups = [
                    g for g, data in self.groups.items() if user in data["users"]
                ]
                if user_groups:
                    groups_text = ", ".join(user_groups)
                    user_node.add(f"[dim]Groups: {groups_text}[/dim]")
                # Show which secrets the user has access to
                user_secrets = [
                    s for s, data in self.secrets.items() if user in data["users"]
                ]
                if user_secrets:
                    for secret in sorted(user_secrets):
                        user_node.add(f"🔓 [yellow]{secret}[/yellow]")

        # Add machines section
        if self.machines:
            machines_branch = tree.add("🖥️  [bold yellow]Machines[/bold yellow]")
            for machine in sorted(self.machines.keys()):
                machine_node = machines_branch.add(f"[magenta]{machine}[/magenta]")
                # Show which groups the machine belongs to
                machine_groups = [
                    g for g, data in self.groups.items() if machine in data["machines"]
                ]
                if machine_groups:
                    groups_text = ", ".join(machine_groups)
                    machine_node.add(f"[dim]Groups: {groups_text}[/dim]")
                # Show which secrets the machine has access to
                machine_secrets = [
                    s for s, data in self.secrets.items() if machine in data["machines"]
                ]
                if machine_secrets:
                    for secret in sorted(machine_secrets):
                        machine_node.add(f"🔓 [yellow]{secret}[/yellow]")

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
            table.add_row(secret, users, machines)

        return table

    def create_graphviz_graph(self, output_format="png", filename="sops_hierarchy"):
        """Create a Graphviz graph visualization"""
        if not HAS_GRAPHVIZ:
            raise ImportError(
                "graphviz package is not installed. Run: pip install graphviz"
            )

        dot = graphviz.Digraph(comment="SOPS Access Control Hierarchy")
        dot.attr(rankdir="TB")
        dot.attr("node", fontname="Arial")

        # Style settings
        dot.attr("node", shape="box", style="rounded,filled")

        # Create subgraphs for better organization
        with dot.subgraph(name="cluster_users") as c:
            c.attr(label="Users", style="filled", color="lightgrey")
            for user in sorted(self.users.keys()):
                c.node(f"user_{user}", user, fillcolor="lightblue", shape="ellipse")

        with dot.subgraph(name="cluster_machines") as c:
            c.attr(label="Machines", style="filled", color="lightgrey")
            for machine in sorted(self.machines.keys()):
                c.node(
                    f"machine_{machine}", machine, fillcolor="lightyellow", shape="box"
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


def main():
    parser = argparse.ArgumentParser(
        description="Visualize SOPS access control hierarchy",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                     # Show tree view in terminal
  %(prog)s --table            # Show access matrix table
  %(prog)s --graph            # Generate graph visualization (requires graphviz)
  %(prog)s --all              # Show all visualizations
        """,
    )
    parser.add_argument(
        "--sops-root", default="./sops", help="Path to SOPS root directory"
    )
    parser.add_argument("--table", action="store_true", help="Show access matrix table")
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
    if not any([args.table, args.graph, args.all]):
        args.tree = True
    else:
        args.tree = args.all
        args.table = args.table or args.all
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


if __name__ == "__main__":
    main()
