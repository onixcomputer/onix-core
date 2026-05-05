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
        package = pkgs.prettier;
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
  onixNix = inputs'.nix.nix.overrideAttrs (_: {
    doCheck = false;
  });
  clan-cli = inputs'.clan-core.clan-cli.override { nix = onixNix; };

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
        (pkgs.python3.withPackages (ps: [
          ps.pytest
          ps.vcrpy
          ps.pytest-vcr
        ]))
        self'.packages.nix-eval-warnings
        self'.packages.dumbpipe
        self'.packages.sendme
        self'.packages.verify-deploy
        self'.packages.claude-md
      ]
      ++ lib.optionals (self'.packages ? tracey) [ self'.packages.tracey ]
      ++ [
        self.inputs.drift.packages.${pkgs.stdenv.hostPlatform.system}.default
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
        if [ -f .env ]; then
          set -a
          source .env
          set +a
        fi

        ${preCommitEval.installationScript}
      '';
    };

    # Minimal shell with just clan CLI
    minimal = pkgs.mkShell {
      packages = [
        clan-cli
      ];

      shellHook = "";
    };

    # Analysis shell for infrastructure inspection
    analysis = pkgs.mkShell {
      packages = [
        self'.packages.acl
        self'.packages.vars
        self'.packages.tags
      ];

      shellHook = "";
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
        ${preCommitEval.installationScript}
      '';
    };
  };
}
