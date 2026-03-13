# Development environment: formatter, pre-commit, MCP servers, and dev shells.
#
# Consolidates formatter.nix, pre-commit.nix, mcp-servers.nix, and devshells.nix
# into a single module. These were previously separate flake-parts modules wired
# together via `config.*`; adios-flake modules communicate through `self'` instead,
# so we evaluate all the dev tooling in one place to avoid circular references.
{
  pkgs,
  lib,
  self,
  self',
  inputs',
  ...
}:
let
  # --- treefmt ---
  treefmtEval = inputs'.treefmt-nix.lib.evalModule pkgs {
    programs = {
      # Nix
      nixfmt.enable = true;
      nixfmt.package = pkgs.nixfmt;
      deadnix.enable = true;

      # Shell
      shellcheck.enable = true;
      shfmt.enable = true;

      # Python
      mypy.enable = true;
      ruff = {
        check = true;
        format = true;
      };

      # Rust
      rustfmt.enable = true;

      # C/C++
      clang-format.enable = true;

      # Web / data
      prettier = {
        enable = true;
        includes = [
          "*.cjs"
          "*.css"
          "*.html"
          "*.js"
          "*.json"
          "*.json5"
          "*.jsx"
          "*.md"
          "*.mdx"
          "*.mjs"
          "*.scss"
          "*.ts"
          "*.tsx"
          "*.vue"
          "*.yaml"
          "*.yml"
        ];
        excludes = [ "*/asciinema-player/*" ];
      };
    };

    settings = {
      global.excludes = [
        "*.png"
        "*.svg"
        "package-lock.json"
        "*.jpeg"
        "*.gitignore"
        ".vscode/*"
        "*.toml"
        "*.clan-flake"
        "*.code-workspace"
        "*.pub"
        "*.priv"
        "*.typed"
        "*.age"
        "*.list"
        "*.desktop"
        "*.lock"

        # ignore symlink
        ".pre-commit-config.yaml"
        "*_test_cert"
        "*_test_key"
        "*/gnupg-home/*"
        "*/sops/secrets/*"
        "vars/*"
        "**/node_modules/*"
        "**/.mypy_cache/*"

        # onix-core specific
        "archive/*"

        # exclude markdown files to prevent timestamp changes
        "*.md"

        # machine-generated
        "*/facter.json"
        "inventory.json"
      ];

      formatter = {
        # Shell: format .sh files and .envrc
        shfmt.includes = [
          "*.sh"
          "*.envrc"
        ];
        shellcheck.includes = [
          "*.sh"
          "scripts/pre-commit"
        ];
        shellcheck.options = [
          "--external-sources"
          "--source-path=SCRIPTDIR"
        ];

        # Python: format all .py files, skip generated models
        ruff-format.excludes = [
          "*/clan_lib/nix_models/*"
        ];
        ruff-check.excludes = [
          "*/clan_lib/nix_models/*"
        ];
      };
    };

    programs.mypy.directories = { };
  };

  treefmtWrapper = treefmtEval.config.build.wrapper;

  # --- pre-commit ---
  # Use pre-commit-hooks-nix's module system directly (no flake-parts wrapper)
  preCommitSrc = inputs'.pre-commit-hooks-nix;

  preCommitEval =
    (lib.evalModules {
      modules = [
        "${preCommitSrc}/modules/all-modules.nix"
        {
          config = {
            rootSrc = self.outPath;
            package = pkgs.pre-commit;
            tools = import "${preCommitSrc}/nix/call-tools.nix" pkgs;
            hooks = {
              treefmt = {
                enable = true;
                package = treefmtWrapper;
                pass_filenames = false;
              };
              statix.enable = true;
              deadnix.enable = true;
            };
            excludes = [
              "^vars/"
              "^sops/"
              "\\.age$"
              "\\.png$|\\.jpg$|\\.svg$"
              "flake\\.lock$"
              "^archive/"
            ];
          };
        }
      ];
      specialArgs = {
        inherit pkgs;
      };
    }).config;

  # --- MCP servers ---
  mcpLib = inputs'.mcp-servers-nix.lib;

  mcpBaseConfig = {
    programs = {
      filesystem = {
        enable = true;
        args = [ "." ];
      };
      git.enable = true;
      context7.enable = true;
      memory.enable = true;
      time.enable = true;
      sequential-thinking.enable = true;
      fetch.enable = true;
      playwright.enable = true;
    };
  };

  mcpClaudeConfig = lib.recursiveUpdate mcpBaseConfig {
    flavor = "claude-code";
    programs.filesystem.args = [
      "."
      ".."
    ];
  };

  mcpVscodeConfig = lib.recursiveUpdate mcpBaseConfig {
    flavor = "vscode";
  };

  mcpClaudeEval = mcpLib.evalModule pkgs mcpClaudeConfig;
  mcpVscodeEval = mcpLib.evalModule pkgs mcpVscodeConfig;

  mcpClaudeConfigFile = mcpClaudeEval.config.configFile;
  mcpVscodeConfigFile = mcpVscodeEval.config.configFile;

  # Collect enabled MCP server packages from the claude flavor
  mcpPackages =
    let
      programs = lib.filterAttrs (_: v: v.enable or false) mcpClaudeEval.config.programs;
    in
    lib.mapAttrsToList (_: v: v.package) programs;

  mcpShellHook = ''
    ln -sf ${mcpClaudeConfigFile} .mcp.json
    mkdir -p .vscode
    ln -sf ${mcpVscodeConfigFile} .vscode/mcp.json
  '';

in
{
  # treefmt formatter output
  formatter = treefmtWrapper;

  # pre-commit check
  checks.pre-commit = preCommitEval.run;

  devShells = {
    # Full development environment with all tools
    default = pkgs.mkShell {
      packages = [
        inputs'.clan-core.clan-cli
        preCommitEval.package
        self'.packages.acl
        self'.packages.vars
        self'.packages.tags
        self'.packages.merge-when-green
        self'.packages.nix-eval-warnings
        self'.packages.iroh-ssh
        self'.packages.claude-md
        self'.packages.tracey
        self'.packages.ccusage
        self'.packages.abp
        pkgs.nix-output-monitor
        (pkgs.writeShellScriptBin "eval-warnings" ''
          if [ -z "$1" ]; then
            echo "Usage: eval-warnings <flake-ref>"
            echo "Example: eval-warnings '.#checks'"
            exit 1
          fi
          exec ${self'.packages.nix-eval-warnings}/bin/nix-eval-warnings "$@"
        '')
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
        inputs'.mics-skills.browser-cli
        inputs'.mics-skills.context7-cli
        inputs'.mics-skills.db-cli
        inputs'.mics-skills.gmaps-cli
        inputs'.mics-skills.kagi-search
        inputs'.mics-skills.pexpect-cli
        inputs'.mics-skills.screenshot-cli
        inputs'.mics-skills.weather-cli
      ]
      ++ mcpPackages;

      shellHook = ''
        echo "Clan Infrastructure Development Shell"
        echo "Available commands:"
        echo "  clan             - Clan CLI for infrastructure management"
        echo "  build            - Build a machine configuration (test locally)"
        echo "  validate         - Run nix fmt and pre-commit checks"
        echo "  nix-prefetch-sri - Get SRI hash for a URL"
        echo ""
        echo "Analysis commands:"
        echo "  acl              - Analyze Clan secret ownership"
        echo "  vars             - Analyze Clan vars ownership"
        echo "  tags             - Analyze Clan machine tags"

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
        echo "  abp              - Agent Browser Protocol server"
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

        ${preCommitEval.installationScript}

        # Configure MCP servers for AI coding assistants
        ${mcpShellHook}
      '';
    };

    # Minimal shell with just clan CLI
    minimal = pkgs.mkShell {
      packages = [
        inputs'.clan-core.clan-cli
      ];

      shellHook = ''
        echo "Minimal Clan Shell"
        echo "Available: clan"
      '';
    };

    # Analysis shell for infrastructure inspection
    analysis = pkgs.mkShell {
      packages = [
        self'.packages.acl
        self'.packages.vars
        self'.packages.tags
      ];

      shellHook = ''
        echo "Analysis Shell"
        echo "Available: acl, vars, tags"
      '';
    };

    # CI shell with validation tools only
    ci = pkgs.mkShell {
      packages = [
        preCommitEval.package
        (pkgs.writeShellScriptBin "validate" ''
          echo "Running nix fmt..."
          nix fmt && echo "Running pre-commit checks..." && pre-commit run --all-files
        '')
      ];

      shellHook = ''
        echo "CI Shell"
        echo "Available: validate, pre-commit"
        ${preCommitEval.installationScript}
      '';
    };
  };
}
