{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python3
    python3Packages.rich
    python3Packages.graphviz
    graphviz
  ];

  shellHook = ''
    echo "SOPS Visualization Environment"
    echo "Available commands:"
    echo "  ./visualize_sops_simple.py    - Simple text-based visualizer (no deps)"
    echo "  ./visualize_sops_hierarchy.py - Rich TUI visualizer"
    echo "  dot -Tpng file.dot -o file.png - Convert DOT files to images"
  '';
}
