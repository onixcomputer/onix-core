#!/usr/bin/env python3
"""
Access Control List (ACL) viewer for SOPS hierarchy.
Shows users, machines, groups, and their access to secrets with age public keys.
"""

import argparse
import sys
from pathlib import Path

# Import both implementations
# Add current directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

try:
    from sops_viz_simple_impl import SimpleSOPSVisualizer
except ImportError as e:
    print(f"Error: Cannot import simple SOPS visualizer: {e}", file=sys.stderr)
    sys.exit(1)

try:
    from rich.console import Console
    from sops_viz_rich_impl import SOPSHierarchyAnalyzer

    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False
    print("Warning: Rich library not available. Rich mode disabled.", file=sys.stderr)


def main() -> None:
    """Main entry point for ACL viewer."""
    parser = argparse.ArgumentParser(
        description="Access Control List (ACL) viewer for SOPS hierarchy",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                     # Show tree view with rich formatting
  %(prog)s --basic             # Show tree view with simple formatting
  %(prog)s --table            # Show access matrix table
  %(prog)s --keys             # Show age public keys table
  %(prog)s --graph            # Generate graph visualization (requires graphviz)
  %(prog)s --all              # Show all visualizations
        """,
    )
    parser.add_argument(
        "--sops-root", default="./sops", help="Path to SOPS root directory"
    )
    parser.add_argument(
        "--basic",
        action="store_true",
        help="Use simple text formatting instead of rich",
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
        help="Graph output format (default: png)",
    )
    parser.add_argument(
        "--graph-filename",
        default="sops_hierarchy",
        help="Graph output filename (default: sops_hierarchy)",
    )
    parser.add_argument(
        "--all", action="store_true", help="Show all available visualizations"
    )

    args = parser.parse_args()

    # Validate sops root directory
    sops_root = Path(args.sops_root)
    if not sops_root.exists():
        print(
            f"Error: SOPS root directory '{sops_root}' does not exist", file=sys.stderr
        )
        sys.exit(1)

    # Determine which implementation to use
    use_rich = not args.basic and RICH_AVAILABLE

    # If no specific visualization is requested, default to tree
    if not any([args.table, args.keys, args.graph, args.all]):
        show_tree = True
    else:
        show_tree = args.all
        args.table = args.table or args.all
        args.keys = args.keys or args.all
        args.graph = args.graph or args.all

    if use_rich:
        # Use rich implementation
        console = Console()
        analyzer = SOPSHierarchyAnalyzer(sops_root)
        analyzer.scan_structure()

        # Show tree view
        if show_tree:
            tree = analyzer.create_rich_tree()
            console.print(tree)
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
            try:
                output_file = analyzer.create_graphviz_graph(
                    args.graph_format, args.graph_filename
                )
                console.print(f"✓ Generated graph: {output_file}")
            except ImportError as e:
                console.print(f"[red]Error: {e}[/red]")
                console.print("[yellow]Install graphviz: pip install graphviz[/yellow]")
    else:
        # Use simple implementation
        visualizer = SimpleSOPSVisualizer(sops_root)
        visualizer.scan_structure()

        # Show tree view
        if show_tree:
            visualizer.display_hierarchy()

        # Show access matrix
        if args.table:
            visualizer.display_access_matrix()

        # Show keys table
        if args.keys:
            visualizer.display_keys_table()

        # Generate graph (not supported in simple mode)
        if args.graph:
            print("Graph generation requires rich mode. Use without --basic flag.")


if __name__ == "__main__":
    main()
