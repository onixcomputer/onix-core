{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      config,
      ...
    }:
    {
      devShells = {
        default = pkgs.mkShell {
          packages = [
            inputs.clan-core.packages.${system}.clan-cli
            config.pre-commit.settings.package
          ];

          shellHook = ''
            echo "Clan Infrastructure Development Shell"
            echo "Available commands:"
            echo "  clan       - Clan CLI for infrastructure management"
            echo "  pre-commit - Code quality checks and formatting"
            echo ""
            ${config.pre-commit.installationScript}
          '';
        };
      };
    };
}
