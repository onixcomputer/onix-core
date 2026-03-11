_: {
  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        programs = {
          # Nix
          nixfmt.enable = true;
          nixfmt.package = pkgs.nixfmt-rfc-style;
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
      };

      treefmt.programs.mypy.directories = { };
    };
}
