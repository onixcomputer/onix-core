# Exportable flake modules for reuse in other flakes
# These can be imported by downstream consumers
_: {
  flake.flakeModules = {
    # Analysis tools module - provides acl, vars, tags, roster commands
    analysis-tools = ../parts/sops-viz.nix;

    # Cloud CLI module - provides cloud infrastructure management
    cloud-cli = ../parts/cloud-cli.nix;

    # Pre-commit configuration module
    pre-commit = ../parts/pre-commit.nix;

    # Formatter configuration module
    formatter = ../parts/formatter.nix;
  };
}
