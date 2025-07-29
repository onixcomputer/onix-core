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
            (pkgs.writeShellScriptBin "nix-prefetch-sri" ''
              if [ -z "$1" ]; then
                echo "Usage: nix-prefetch-sri <url>"
                exit 1
              fi
              ${pkgs.curl}/bin/curl -sL "$1" | ${pkgs.nix}/bin/nix hash file --sri /dev/stdin
            '')
            (pkgs.writeShellScriptBin "build" ''
              if [ -z "$1" ]; then
                echo "Usage: build <machine-name>"
                exit 1
              fi
              nix build .#nixosConfigurations.$1.config.system.build.toplevel
            '')
            (pkgs.writeShellScriptBin "validate" ''
              echo "Running nix fmt..."
              nix fmt && echo "Running pre-commit checks..." && pre-commit run --all-files
            '')
          ];

          shellHook = ''
            echo "Clan Infrastructure Development Shell"
            echo "Available commands:"
            echo "  clan             - Clan CLI for infrastructure management"
            echo "  build            - Build a machine configuration (test locally)"
            echo "  validate         - Run nix fmt and pre-commit checks"
            echo "  nix-prefetch-sri - Get SRI hash for a URL"
            echo ""
            ${config.pre-commit.installationScript}
          '';
        };
      };
    };
}
