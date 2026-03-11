# Development shells for onix-core
# Provides multiple specialized environments for different workflows
_: {
  perSystem =
    {
      pkgs,
      inputs',
      config,
      ...
    }:
    {
      devShells = {
        # Full development environment with all tools
        default = pkgs.mkShell {
          packages = [
            inputs'.clan-core.packages.clan-cli
            config.pre-commit.settings.package
            config.packages.acl
            config.packages.vars
            config.packages.tags
            config.packages.roster
            config.packages.cloud-cli
            config.packages.merge-when-green
            config.packages.nix-eval-warnings
            config.packages.iroh-ssh
            config.packages.claude-md
            config.packages.tracey
            config.packages.ccusage
            (pkgs.writeShellScriptBin "eval-warnings" ''
              if [ -z "$1" ]; then
                echo "Usage: eval-warnings <flake-ref>"
                echo "Example: eval-warnings '.#checks'"
                exit 1
              fi
              exec ${config.packages.nix-eval-warnings}/bin/nix-eval-warnings "$@"
            '')
            pkgs.terranix
            pkgs.opentofu
            pkgs.awscli2
            pkgs.jq
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
              if command -v nom &> /dev/null; then
                nom build .#nixosConfigurations.$1.config.system.build.toplevel
              else
                nix build .#nixosConfigurations.$1.config.system.build.toplevel
              fi
            '')
            (pkgs.writeShellScriptBin "validate" ''
              echo "Running nix fmt..."
              nix fmt && echo "Running pre-commit checks..." && pre-commit run --all-files
            '')
            # AI agent CLI tools (mics-skills)
            inputs'.mics-skills.packages.browser-cli
            inputs'.mics-skills.packages.context7-cli
            inputs'.mics-skills.packages.db-cli
            inputs'.mics-skills.packages.gmaps-cli
            inputs'.mics-skills.packages.kagi-search
            inputs'.mics-skills.packages.pexpect-cli
            inputs'.mics-skills.packages.screenshot-cli
            inputs'.mics-skills.packages.weather-cli
          ]
          ++ config.mcp-servers.packages;

          shellHook = ''
            echo "Clan Infrastructure Development Shell"
            echo "Available commands:"
            echo "  clan             - Clan CLI for infrastructure management"
            echo "  build            - Build a machine configuration (test locally)"
            echo "  cloud            - Cloud infrastructure management (create/status/destroy)"
            echo "  validate         - Run nix fmt and pre-commit checks"
            echo "  nix-prefetch-sri - Get SRI hash for a URL"
            echo ""
            echo "Analysis commands:"
            echo "  acl              - Analyze Clan secret ownership"
            echo "  vars             - Analyze Clan vars ownership"
            echo "  tags             - Analyze Clan machine tags"
            echo "  roster           - Analyze Clan user roster configurations"
            echo ""
            echo "AI agent tools:"
            echo "  browser-cli    - Firefox browser automation"
            echo "  context7-cli   - Library documentation from Context7"
            echo "  db-cli         - Deutsche Bahn train connections"
            echo "  gmaps-cli      - Google Maps search/directions"
            echo "  kagi-search    - Web search with Kagi AI summaries"
            echo "  pexpect-cli    - Interactive terminal automation"
            echo "  screenshot-cli - Screenshots (grim/spectacle/macOS)"
            echo "  weather-cli    - Weather forecasts (DWD data)"
            echo ""
            echo "Workflow tools:"
            echo "  merge-when-green - Auto-create PRs and merge when CI passes"
            echo "  eval-warnings    - Extract Nix evaluation warnings"
            echo "  iroh-ssh         - P2P SSH without public IPs or VPN"
            echo "  claude-md        - Centralize CLAUDE.local.md across repos"
            echo "  tracey           - Spec coverage tracking (impl/verify annotations)"
            echo "  ccusage          - Claude Code token usage analysis"
            echo ""

            if [ -f .env ]; then
              echo "Loading AWS credentials..."
              set -a
              source .env
              set +a

              # Check if AWS credentials are actually set
              if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
                echo "  AWS credentials loaded."
                echo "  Cloud provisioning available."
              else
                echo "  .env file found but AWS credentials not set."
                echo "  Cloud provisioning unavailable."
              fi
            else
              echo "  No .env file found."
              echo "  Cloud provisioning unavailable."
            fi
            echo ""

            ${config.pre-commit.installationScript}

            # Configure MCP servers for AI coding assistants
            ${config.mcp-servers.shellHook}
          '';
        };

        # Minimal shell with just clan CLI
        minimal = pkgs.mkShell {
          packages = [
            inputs'.clan-core.packages.clan-cli
          ];

          shellHook = ''
            echo "Minimal Clan Shell"
            echo "Available: clan"
          '';
        };

        # Cloud-focused shell for infrastructure work
        cloud = pkgs.mkShell {
          packages = [
            config.packages.cloud-cli
            pkgs.terranix
            pkgs.opentofu
            pkgs.awscli2
            pkgs.jq
          ];

          shellHook = ''
            echo "Cloud Infrastructure Shell"
            echo "Available: cloud, tofu, terranix, aws"
            echo ""
            if [ -f .env ]; then
              set -a
              source .env
              set +a
              if [ -n "$AWS_ACCESS_KEY_ID" ]; then
                echo "AWS credentials loaded."
              fi
            fi
          '';
        };

        # Analysis shell for infrastructure inspection
        analysis = pkgs.mkShell {
          packages = [
            config.packages.acl
            config.packages.vars
            config.packages.tags
            config.packages.roster
          ];

          shellHook = ''
            echo "Analysis Shell"
            echo "Available: acl, vars, tags, roster"
          '';
        };

        # CI shell with validation tools only
        ci = pkgs.mkShell {
          packages = [
            config.pre-commit.settings.package
            (pkgs.writeShellScriptBin "validate" ''
              echo "Running nix fmt..."
              nix fmt && echo "Running pre-commit checks..." && pre-commit run --all-files
            '')
          ];

          shellHook = ''
            echo "CI Shell"
            echo "Available: validate, pre-commit"
            ${config.pre-commit.installationScript}
          '';
        };
      };
    };
}
