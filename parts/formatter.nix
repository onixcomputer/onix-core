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
            "*.typed"
            "*.age"
            "*.list"
            "*.desktop"
            # ignore symlink
            "docs/site/manual/contribute.md"
            "*_test_cert"
            "*_test_key"
            "*/gnupg-home/*"
            "*/sops/secrets/*"
            "vars/*"
            "*.md"

            "checks/lib/ssh/privkey"
            "checks/lib/ssh/pubkey"
            "checks/matrix-synapse/synapse-registration_shared_secret"
            "checks/mumble/machines/peer1/facts/mumble-cert"
            "checks/mumble/machines/peer2/facts/mumble-cert"
            "checks/secrets/clan-secrets"
            "checks/secrets/sops/groups/group/machines/machine"
            "checks/syncthing/introducer/introducer_device_id"
            "checks/syncthing/introducer/introducer_test_api"
            "docs/site/static/asciinema-player/asciinema-player.css"
            "docs/site/static/asciinema-player/asciinema-player.min.js"
            "nixosModules/clanCore/vars/secret/sops/eval-tests/populated/vars/my_machine/my_generator/my_secret"
            "pkgs/clan-cli/tests/data/gnupg.conf"
            "pkgs/clan-cli/tests/data/password-store/.gpg-id"
            "pkgs/clan-cli/tests/data/ssh_host_ed25519_key"
            "pkgs/clan-cli/tests/data/sshd_config"
            "pkgs/clan-vm-manager/.vscode/lhebendanz.weaudit"
            "pkgs/clan-vm-manager/bin/clan-vm-manager"
            "pkgs/distro-packages/vagrant_insecure_key"
            "sops/secrets/test-backup-age.key/secret"
          ];
          formatter = {
            ruff-format.includes = [
              "*/bin/clan"
              "*/bin/clan-app"
              "*/bin/clan-config"
            ];
            shellcheck.includes = [ "scripts/pre-commit" ];
          };
        };
      };
      treefmt.programs.mypy.directories = { };
    };
}
