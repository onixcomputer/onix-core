# Verify wrapped Helix and zen wire hx-oil into their generated wrappers
# and that the helper emits .hxoil manifests.
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

  hxModule = import ../inventory/home-profiles/brittonr/base/helix/helix.nix {
    inputs = evalInputs;
    inherit pkgs;
    config = fakeConfig;
  };
  zenModule = import ../inventory/home-profiles/brittonr/base/helix/helix-zen.nix {
    inputs = evalInputs;
    inherit pkgs;
    config = fakeConfig;
  };

  hxWrapper = builtins.head hxModule.home.packages;
  zenOnly = builtins.head zenModule.home.packages;
  hxOil = self.packages.${system}.hx-oil;
  hxOilPath = "${hxOil}/bin";
  hxOilBin = "${hxOil}/bin/hx-oil";
in
{
  checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    helix-directory-buffer-integration = pkgs.runCommand "helix-directory-buffer-integration" { } ''
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

      config_root_from_script() {
        sed -n 's/^export XDG_CONFIG_HOME="\(.*\)"$/\1/p' "$1" | head -n1
      }

      hx_script="$(readlink -f ${hxWrapper}/bin/hx)"
      zen_script="$(readlink -f ${zenOnly}/bin/zen)"
      hx_config_root="$(config_root_from_script "$hx_script")"
      zen_config_root="$(config_root_from_script "$zen_script")"

      assert_contains '${hxOilPath}' "$hx_script"
      assert_contains '${hxOilBin} render --from' "$hx_config_root"
      assert_contains '${hxOilBin} apply' "$hx_config_root"
      assert_contains '${hxOilBin} refresh' "$hx_config_root"
      assert_contains '${hxOilBin} open-at-line' "$hx_config_root"
      assert_contains '${hxOilBin} parent' "$hx_config_root"

      assert_contains '${hxOilPath}' "$zen_script"
      assert_contains '${hxOilBin} render --from' "$zen_config_root"
      assert_contains '${hxOilBin} apply' "$zen_config_root"
      assert_contains '${hxOilBin} refresh' "$zen_config_root"
      assert_contains '${hxOilBin} open-at-line' "$zen_config_root"
      assert_contains '${hxOilBin} parent' "$zen_config_root"

      export XDG_STATE_HOME="$TMPDIR/state"
      mkdir -p "$TMPDIR/root"
      touch "$TMPDIR/root/keep.txt"
      manifest="$(${hxOilBin} render --from "$TMPDIR/root")"
      case "$manifest" in
        *.hxoil) ;;
        *)
          echo "expected .hxoil manifest path, got: $manifest" >&2
          exit 1
          ;;
      esac
      [ -f "$manifest" ]
      grep -F '# hx-oil root: ' "$manifest" >/dev/null

      touch "$out"
    '';
  };
}
