_: {
  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        programs = {
          shellcheck.enable = true;
          mypy.enable = true;
          nixfmt.enable = true;
          nixfmt.package = pkgs.nixfmt-rfc-style;
          deadnix.enable = true;
          clang-format.enable = true;
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
          ruff = {
            check = true;
            format = true;
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
            # ignore symlink
            ".pre-commit-config.yaml"
            "*_test_cert"
            "*_test_key"
            "*/gnupg-home/*"
            "*/sops/secrets/*"
            "vars/*"
            # prettier messes up our mkdocs flavoured markdown
            "*.md"
            "**/node_modules/*"
            "**/.mypy_cache/*"

            # onix-core specific
            "archive/*"
          ];
          formatter = {
            ruff-format.includes = [
              "*/bin/clan"
              "*/bin/clan-app"
              "*/bin/clan-config"
            ];
            ruff-format.excludes = [
              "*/clan_lib/nix_models/*"
            ];
            shellcheck.includes = [ "scripts/pre-commit" ];
          };
        };
      };
      treefmt.programs.mypy.directories = { };
    };
}
