# Development environment: formatter, pre-commit, and dev shells.
#
# Consolidates formatter.nix, pre-commit.nix, and devshells.nix into a single
# module. These were previously separate flake-parts modules wired together via
# `config.*`; adios-flake modules communicate through `self'` instead, so we
# evaluate all the dev tooling in one place to avoid circular references.
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
      # Nix — priority: deadnix (1) → statix (2) → nixfmt (3)
      # deadnix removes unused code, statix catches anti-patterns, nixfmt formats.
      deadnix.enable = true;
      deadnix.priority = 1;

      statix.enable = true;
      statix.priority = 2;

      nixfmt = {
        enable = true;
        package = pkgs.nixfmt;
        priority = 3;
      };

      # Shell
      shellcheck.enable = true;
      shfmt.enable = true;

      # Python
      mypy.enable = true;
      ruff = {
        check = true;
        format = true;
      };

      # Nickel — wrapped to preserve mtime when content is unchanged.
      # Upstream nickel format unconditionally does tmp+rename even for
      # already-formatted files, bumping mtime and tripping treefmt's
      # --fail-on-change. The wrapper saves each file's mtime before
      # formatting and restores it when the content hash is identical.
      nickel = {
        enable = true;
        package = pkgs.writeShellApplication {
          name = "nickel";
          runtimeInputs = [
            pkgs.nickel
            pkgs.coreutils
          ];
          text = ''
            nickel_bin=${pkgs.nickel}/bin/nickel

            if [ "''${1:-}" != "format" ]; then
              exec "$nickel_bin" "$@"
            fi
            shift

            opts=()
            files=()
            for arg in "$@"; do
              case "$arg" in
                -*) opts+=("$arg") ;;
                *)  files+=("$arg") ;;
              esac
            done

            for f in "''${files[@]}"; do
              [ -f "$f" ] || continue
              mtime=$(stat -c %Y "$f")
              hash_before=$(sha256sum "$f" | cut -d' ' -f1)
              "$nickel_bin" format "''${opts[@]}" "$f"
              hash_after=$(sha256sum "$f" | cut -d' ' -f1)
              if [ "$hash_before" = "$hash_after" ]; then
                touch -d "@$mtime" "$f"
              fi
            done
          '';
        };
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
        excludes = [
          "*/asciinema-player/*"
          "*/noctalia/templates/*" # contain {{...}} template syntax
        ];
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

  # clan-cli bundles its own nix; override it with our wasm-capable build
  # so that `builtins.wasm` is available for inventory evaluation.
  # doCheck = false mirrors shared-nix.nix — the overlayfs stale-file-handle
  # test fails in sandbox.
  nix-wasm = inputs'.nix-wasm.nix.overrideAttrs (_: {
    doCheck = false;
  });
  clan-cli = inputs'.clan-core.clan-cli.override { nix = nix-wasm; };

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
        clan-cli
        preCommitEval.package
        self'.packages.acl
        self'.packages.vars
        self'.packages.tags
        self'.packages.merge-when-green
        self'.packages.buildbot-pr-check
        (pkgs.python3.withPackages (ps: [
          ps.pytest
          ps.vcrpy
          ps.pytest-vcr
        ]))
        self'.packages.nix-eval-warnings
        self'.packages.iroh-ssh
        self'.packages.dumbpipe
        self'.packages.sendme
        self'.packages.verify-deploy
        self'.packages.claude-md
        self'.packages.ccusage
      ]
      ++ lib.optionals (self'.packages ? tracey) [ self'.packages.tracey ]
      ++ lib.optionals (self'.packages ? abp) [ self'.packages.abp ]
      ++ [
        self.inputs.drift.packages.${pkgs.stdenv.hostPlatform.system}.default
        self'.packages.clankers
      ]
      ++ [
        pkgs.nickel
        pkgs.nix-output-monitor
        pkgs.sops
        (pkgs.writeShellApplication {
          name = "eval-warnings";
          runtimeInputs = [ self'.packages.nix-eval-warnings ];
          text = ''
            if [ -z "''${1:-}" ]; then
              echo "Usage: eval-warnings <flake-ref>"
              echo "Example: eval-warnings '.#checks'"
              exit 1
            fi
            exec nix-eval-warnings "$@"
          '';
        })
        (pkgs.writeShellApplication {
          name = "nix-prefetch-sri";
          runtimeInputs = [
            pkgs.curl
            pkgs.nix
          ];
          text = ''
            if [ -z "''${1:-}" ]; then
              echo "Usage: nix-prefetch-sri <url>"
              exit 1
            fi
            curl -sL "$1" | nix hash file --sri /dev/stdin
          '';
        })
        (pkgs.writeShellApplication {
          name = "build";
          text = ''
            if [ -z "''${1:-}" ]; then
              echo "Usage: build <machine-name>"
              exit 1
            fi
            if command -v nom &> /dev/null; then
              nom build ".#nixosConfigurations.$1.config.system.build.toplevel"
            else
              nix build ".#nixosConfigurations.$1.config.system.build.toplevel"
            fi
          '';
        })
        (pkgs.writeShellApplication {
          name = "validate";
          text = ''
            echo "Running nix fmt..."
            nix fmt && echo "Running pre-commit checks..." && pre-commit run --all-files
          '';
        })
        # AI agent CLI tools (mics-skills)
        inputs'.mics-skills.browser-cli
        inputs'.mics-skills.context7-cli
        inputs'.mics-skills.db-cli
        inputs'.mics-skills.gmaps-cli
        inputs'.mics-skills.kagi-search
        inputs'.mics-skills.pexpect-cli
        inputs'.mics-skills.screenshot-cli
        inputs'.mics-skills.weather-cli
      ];

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
        echo "Project tools:"
        echo "  drift            - Terminal music player (Tidal/YouTube/Bandcamp)"
        echo "  clankers         - Terminal coding agent"
        echo ""
        echo "Workflow tools:"
        echo "  merge-when-green  - Auto-create PRs and merge when CI passes"
        echo "  buildbot-pr-check - Show buildbot CI failures for a PR"
        echo "  eval-warnings     - Extract Nix evaluation warnings"
        echo "  iroh-ssh         - P2P SSH without public IPs or VPN"
        echo "  dumbpipe         - Cross-device unix pipe over iroh"
        echo "  sendme           - P2P file transfer with blake3 verification"
        echo "  verify-deploy    - Verify deployed machine matches expected build"
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
      '';
    };

    # Minimal shell with just clan CLI
    minimal = pkgs.mkShell {
      packages = [
        clan-cli
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
        (pkgs.writeShellApplication {
          name = "validate";
          text = ''
            echo "Running nix fmt..."
            nix fmt && echo "Running pre-commit checks..." && pre-commit run --all-files
          '';
        })
      ];

      shellHook = ''
        echo "CI Shell"
        echo "Available: validate, pre-commit"
        ${preCommitEval.installationScript}
      '';
    };
  };
}
