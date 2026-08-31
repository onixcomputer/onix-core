# Verify wrapped Helix and zen keep their language and theme integrations
# without retaining the removed hx-oil directory-buffer integration.
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  keymap = wasm.evalNickelFile ../inventory/home-profiles/brittonr/base/keymap.ncl;

  fakeConfig = {
    inherit keymap;
    theme.active = "test-dark";
    helixTheme = {
      dark = { };
      light = { };
    };
    helixZenTheme = {
      dark = { };
      light = { };
    };
    editor = {
      softWrap = {
        maxWrap = 25;
        maxWrapZen = 20;
      };
      inlineDiagnostics = {
        prefixLen = 2;
        maxCount = 3;
      };
      autoSave.timeout = 250;
      textWidth = 80;
      rulers = [ 80 ];
    };
  };

  evalInputs = self.inputs // {
    inherit self;
  };
  helixPkgs = import pkgs.path {
    inherit system;
    config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "replace" ];
  };

  hxModule = import ../inventory/home-profiles/brittonr/base/helix/helix.nix {
    inputs = evalInputs;
    pkgs = helixPkgs;
    config = fakeConfig;
  };
  zenModule = import ../inventory/home-profiles/brittonr/base/helix/helix-zen.nix {
    inputs = evalInputs;
    pkgs = helixPkgs;
    config = fakeConfig;
  };

  hxWrapper = builtins.head hxModule.home.packages;
  zenOnly = builtins.head zenModule.home.packages;
in
{
  checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    helix-wrapper-integration = pkgs.runCommand "helix-wrapper-integration" { } ''
      set -euo pipefail

      assert_contains() {
        local needle="$1"
        local target="$2"
        if [ -d "$target" ]; then
          if ! grep -R -F "$needle" "$target" >/dev/null; then
            echo "missing [$needle] in $target" >&2
            find "$target" -maxdepth 3 -print >&2 || true
            exit 1
          fi
        else
          if ! grep -F "$needle" "$target" >/dev/null; then
            echo "missing [$needle] in $target" >&2
            sed -n '1,200p' "$target" >&2 || true
            exit 1
          fi
        fi
      }

      assert_not_contains() {
        local needle="$1"
        local target="$2"
        if [ -d "$target" ]; then
          if grep -R -F "$needle" "$target" >/dev/null; then
            echo "unexpected [$needle] in $target" >&2
            exit 1
          fi
        else
          if grep -F "$needle" "$target" >/dev/null; then
            echo "unexpected [$needle] in $target" >&2
            sed -n '1,200p' "$target" >&2 || true
            exit 1
          fi
        fi
      }

      config_root_from_script() {
        sed -n 's/^export XDG_CONFIG_HOME="\(.*\)"$/\1/p' "$1" | head -n1
      }

      hx_script="$(readlink -f ${hxWrapper}/bin/hx)"
      zen_script="$(readlink -f ${zenOnly}/bin/zen)"
      hx_config_root="$(config_root_from_script "$hx_script")"
      zen_config_root="$(config_root_from_script "$zen_script")"

      assert_contains '${helixPkgs.steelix}/bin' "$hx_script"
      assert_contains '${helixPkgs.steel}/bin' "$hx_script"
      assert_contains '${helixPkgs.steel-language-server}/bin' "$hx_script"
      assert_contains '${helixPkgs.libxml2}/bin' "$hx_script"
      assert_contains '${helixPkgs.lemminx}/bin' "$hx_script"
      assert_contains '${helixPkgs.taplo}/bin' "$hx_script"
      assert_contains '${helixPkgs.yaml-language-server}/bin' "$hx_script"
      assert_contains '${helixPkgs.vscode-langservers-extracted}/bin' "$hx_script"
      assert_contains '${helixPkgs.bash-language-server}/bin' "$hx_script"
      assert_contains '${helixPkgs.shfmt}/bin' "$hx_script"
      assert_contains '${helixPkgs.prettier}/bin' "$hx_script"
      assert_contains '${helixPkgs.ltex-ls}/bin' "$hx_script"
      assert_contains 'name = "toml"' "$hx_config_root"
      assert_contains 'language-servers = ["taplo"]' "$hx_config_root"
      assert_contains 'command = "${helixPkgs.taplo}/bin/taplo"' "$hx_config_root"
      assert_contains 'name = "yaml"' "$hx_config_root"
      assert_contains 'language-servers = ["yaml-language-server"]' "$hx_config_root"
      assert_contains 'command = "${helixPkgs.yaml-language-server}/bin/yaml-language-server"' "$hx_config_root"
      assert_contains 'name = "json"' "$hx_config_root"
      assert_contains 'language-servers = ["vscode-json-language-server"]' "$hx_config_root"
      assert_contains 'command = "${helixPkgs.vscode-langservers-extracted}/bin/vscode-json-language-server"' "$hx_config_root"
      assert_contains 'name = "bash"' "$hx_config_root"
      assert_contains 'language-servers = ["bash-language-server"]' "$hx_config_root"
      assert_contains 'command = "${helixPkgs.bash-language-server}/bin/bash-language-server"' "$hx_config_root"
      assert_contains 'command = "${helixPkgs.shfmt}/bin/shfmt"' "$hx_config_root"
      assert_contains 'name = "asciidoc"' "$hx_config_root"
      assert_contains 'language-servers = ["ltex-ls"]' "$hx_config_root"
      assert_contains 'command = "${helixPkgs.ltex-ls}/bin/ltex-ls"' "$hx_config_root"
      assert_contains 'name = "xml"' "$hx_config_root"
      assert_contains 'language-servers = ["lemminx"]' "$hx_config_root"
      assert_contains 'command = "${helixPkgs.libxml2}/bin/xmllint"' "$hx_config_root"
      assert_contains 'command = "${helixPkgs.lemminx}/bin/lemminx"' "$hx_config_root"
      assert_contains '"--format"' "$hx_config_root"
      assert_contains 'name = "scheme"' "$hx_config_root"
      assert_contains 'language-servers = ["steel-language-server"]' "$hx_config_root"
      assert_contains 'command = "${helixPkgs.steel-language-server}/bin/steel-language-server"' "$hx_config_root"
      assert_not_contains 'hx-oil' "$hx_script"
      assert_not_contains 'hx-oil' "$hx_config_root"
      assert_not_contains '.hxoil' "$hx_config_root"

      # Noctalia runtime theme: helix must default to the `noctalia` theme
      # (written live at ~/.config/helix/themes/noctalia.toml by Noctalia and
      # overlaid over this immutable seed), with no legacy onix names.
      assert_contains 'theme = "noctalia"' "$hx_config_root"
      test -f "$hx_config_root/helix/themes/noctalia.toml"
      if grep -R -F 'onix-dark' "$hx_config_root" >/dev/null; then
        echo "unexpected onix-dark in $hx_config_root" >&2
        exit 1
      fi
      if grep -R -F 'onix-light' "$hx_config_root" >/dev/null; then
        echo "unexpected onix-light in $hx_config_root" >&2
        exit 1
      fi

      assert_contains '${helixPkgs.steelix}/bin' "$zen_script"
      assert_contains 'theme = "noctalia"' "$zen_config_root"
      assert_not_contains 'hx-oil' "$zen_script"
      assert_not_contains 'hx-oil' "$zen_config_root"
      assert_not_contains '.hxoil' "$zen_config_root"

      touch "$out"
    '';
  };
}
