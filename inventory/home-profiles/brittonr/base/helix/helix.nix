{
  inputs,
  pkgs,
  config,
  ...
}:
let
  k = config.keymap;
  activeTheme = config.theme.active;
  hxOil = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.hx-oil;
  openDirectoryBufferCmd = ''
    :open %sh{path="%{file_path_absolute}"; if [ -n "$path" ]; then path=$(dirname "$path"); else path="%{current_working_directory}"; fi; ${hxOil}/bin/hx-oil render --from "$path"}
  '';
  applyDirectoryBufferCmd = [
    ":write"
    ":sh ${hxOil}/bin/hx-oil apply \"%{file_path_absolute}\""
    ":reload"
  ];
  refreshDirectoryBufferCmd = [
    ":sh ${hxOil}/bin/hx-oil refresh \"%{file_path_absolute}\""
    ":reload"
  ];
  openDirectoryEntryCmd = ''
    :open %sh{${hxOil}/bin/hx-oil open-at-line "%{file_path_absolute}" %{cursor_line}}
  '';
  openParentDirectoryCmd = ''
    :open %sh{${hxOil}/bin/hx-oil parent "%{file_path_absolute}"}
  '';

  # Runtime theme overlay: on launch, create a merged config dir that
  # includes both the immutable store themes and any mutable themes
  # written by Noctalia at ~/.config/helix/themes/.  Store themes are
  # linked first so mutable ones win on conflict.
  helixThemeOverlay = ''
    _store_cfg="$XDG_CONFIG_HOME"
    _merged="''${XDG_CACHE_HOME:-$HOME/.cache}/helix-wrapper-hx"
    _mutable="$HOME/.config/helix/themes"
    mkdir -p "$_merged/helix/themes"
    for f in "$_store_cfg"/helix/*; do
      [ -e "$f" ] || continue
      case "$(basename "$f")" in
        themes) ;;
        *) ln -sfn "$f" "$_merged/helix/" ;;
      esac
    done
    for t in "$_store_cfg"/helix/themes/*; do
      [ -e "$t" ] && ln -sf "$t" "$_merged/helix/themes/"
    done
    if [ -d "$_mutable" ]; then
      for t in "$_mutable"/*.toml; do
        [ -e "$t" ] && ln -sf "$t" "$_merged/helix/themes/"
      done
    fi
    export XDG_CONFIG_HOME="$_merged"
  '';
in
{
  home.packages = [
    (inputs.wrappers.wrapperModules.helix.apply {
      inherit pkgs;

      preHook = helixThemeOverlay;

      extraPackages = with pkgs; [
        cargo
        rustc
        clippy
        rustfmt
        rust-analyzer
        nls
        hxOil
      ];

      settings = {
        theme = activeTheme;
        editor = {
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
        };
        keys.normal = {
          ${k.leader} = {
            ${k.leaderActions.filePicker} = "file_picker";
            ${k.leaderActions.save} = ":w";
            ${k.leaderActions.quit} = ":q";
            ${k.leaderActions.directoryBuffer} = openDirectoryBufferCmd;
            ${k.leaderActions.directoryApply} = applyDirectoryBufferCmd;
            ${k.leaderActions.directoryRefresh} = refreshDirectoryBufferCmd;
            ${k.leaderActions.directoryOpenEntry} = openDirectoryEntryCmd;
            ${k.leaderActions.directoryParent} = openParentDirectoryCmd;
          };
        };
      };
      languages.language = [
        {
          name = "nix";
          auto-format = true;
          formatter.command = "${pkgs.nixfmt}/bin/nixfmt";
          language-servers = [ "nil" ];
        }
        {
          name = "rust";
          auto-format = true;
          formatter.command = "${pkgs.rustfmt}/bin/rustfmt";
          formatter.args = [
            "--edition"
            "2024"
          ];
          language-servers = [ "rust-analyzer" ];
        }
        {
          name = "python";
          auto-format = true;
          language-servers = [
            "ruff"
            "jedi-language-server"
          ];
          formatter.command = "${pkgs.ruff}/bin/ruff";
          formatter.args = [
            "format"
            "-"
          ];
        }
        {
          name = "markdown";
          auto-format = false;
          language-servers = [ "marksman" ];
        }
        {
          name = "typst";
          auto-format = true;
          language-servers = [ "tinymist" ];
        }
        {
          name = "nickel";
          auto-format = true;
          language-servers = [ "nls" ];
        }
      ];

      languages.language-server = {
        nil = {
          command = "${pkgs.nil}/bin/nil";
        };
        rust-analyzer = {
          command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
          config = {
            check = {
              command = "clippy";
            };
            inlayHints = {
              bindingModeHints.enable = false;
              closingBraceHints.minLines = 10;
              closureReturnTypeHints.enable = "with_block";
              discriminantHints.enable = "fieldless";
              lifetimeElisionHints.enable = "skip_trivial";
              typeHints.hideClosureInitialization = false;
            };
            cargo = {
              allFeatures = true;
            };
            procMacro = {
              enable = true;
            };
            rustfmt = {
              extraArgs = [
                "--edition"
                "2021"
              ];
            };
            # Enable support for standalone Rust files (like Rustlings exercises)
            diagnostics = {
              enable = true;
              disabled = [ ];
              experimental = {
                enable = true;
              };
            };
            files = {
              excludeDirs = [ ];
            };
          };
        };
        ruff = {
          command = "${pkgs.ruff}/bin/ruff";
          args = [ "server" ];
        };
        jedi-language-server = {
          command = "${pkgs.python3Packages.jedi-language-server}/bin/jedi-language-server";
        };
        marksman = {
          command = "${pkgs.marksman}/bin/marksman";
          args = [ "server" ];
        };
        tinymist = {
          command = "${pkgs.tinymist}/bin/tinymist";
        };
        nls = {
          command = "${pkgs.nls}/bin/nls";
        };
      };

      themes.${activeTheme} = config.helixTheme.dark;

      themes.${builtins.replaceStrings [ "-dark" ] [ "-light" ] activeTheme} = config.helixTheme.light;
    }).wrapper
  ];

  home.sessionVariables.EDITOR = "hx";
}
