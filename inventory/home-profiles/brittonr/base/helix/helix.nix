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
  rememberAlternateShell = ''
    current="%{file_path_absolute}"; case "$current" in *.hxoil) ${hxOil}/bin/hx-oil remember-alternate "$current" >/dev/null ;; esac;
  '';
  openDirectoryBufferCmd = ''
    :open %sh{${rememberAlternateShell} path="%{file_path_absolute}"; if [ -n "$path" ]; then path=$(dirname "$path"); else path="%{current_working_directory}"; fi; ${hxOil}/bin/hx-oil render --from "$path"}
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
    :open %sh{${rememberAlternateShell} ${hxOil}/bin/hx-oil open-at-line "%{file_path_absolute}" %{cursor_line}}
  '';
  openParentDirectoryCmd = ''
    :open %sh{${rememberAlternateShell} ${hxOil}/bin/hx-oil parent "%{file_path_absolute}"}
  '';
  toggleDirectoryMarkCmd = [
    ":sh ${hxOil}/bin/hx-oil mark-toggle \"%{file_path_absolute}\" %{cursor_line}"
    ":reload"
  ];
  toggleDirectoryDeleteFlagCmd = [
    ":sh ${hxOil}/bin/hx-oil flag-delete \"%{file_path_absolute}\" %{cursor_line}"
    ":reload"
  ];
  clearDirectoryMarksCmd = [
    ":sh ${hxOil}/bin/hx-oil clear-marks \"%{file_path_absolute}\""
    ":reload"
  ];
  previewDirectoryCopyCmd = ":sh ${hxOil}/bin/hx-oil op copy \"%{file_path_absolute}\"";
  applyDirectoryCopyCmd = [
    ":sh ${hxOil}/bin/hx-oil op copy \"%{file_path_absolute}\" --execute"
    ":reload"
  ];
  previewDirectoryMoveCmd = ":sh ${hxOil}/bin/hx-oil op move \"%{file_path_absolute}\"";
  applyDirectoryMoveCmd = [
    ":sh ${hxOil}/bin/hx-oil op move \"%{file_path_absolute}\" --execute"
    ":reload"
  ];
  previewDirectorySymlinkCmd = ":sh ${hxOil}/bin/hx-oil op symlink \"%{file_path_absolute}\"";
  applyDirectorySymlinkCmd = [
    ":sh ${hxOil}/bin/hx-oil op symlink \"%{file_path_absolute}\" --execute"
    ":reload"
  ];
  previewDirectoryRelativeSymlinkCmd = ":sh ${hxOil}/bin/hx-oil op relative-symlink \"%{file_path_absolute}\"";
  applyDirectoryRelativeSymlinkCmd = [
    ":sh ${hxOil}/bin/hx-oil op relative-symlink \"%{file_path_absolute}\" --execute"
    ":reload"
  ];
  previewDirectoryLowerCmd = ":sh ${hxOil}/bin/hx-oil transform lower \"%{file_path_absolute}\"";
  applyDirectoryLowerCmd = [
    ":sh ${hxOil}/bin/hx-oil transform lower \"%{file_path_absolute}\" --execute"
    ":reload"
  ];
  previewDirectoryUpperCmd = ":sh ${hxOil}/bin/hx-oil transform upper \"%{file_path_absolute}\"";
  applyDirectoryUpperCmd = [
    ":sh ${hxOil}/bin/hx-oil transform upper \"%{file_path_absolute}\" --execute"
    ":reload"
  ];
  insertDirectorySubdirCmd = [
    ":sh ${hxOil}/bin/hx-oil subdir insert \"%{file_path_absolute}\" %{cursor_line}"
    ":reload"
  ];
  collapseDirectorySubdirCmd = [
    ":sh ${hxOil}/bin/hx-oil subdir collapse \"%{file_path_absolute}\" %{cursor_line}"
    ":reload"
  ];
  refreshDirectorySubdirCmd = [
    ":sh ${hxOil}/bin/hx-oil subdir refresh \"%{file_path_absolute}\" %{cursor_line}"
    ":reload"
  ];

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
            ${k.leaderActions.directoryMarkToggle} = toggleDirectoryMarkCmd;
            ${k.leaderActions.directoryFlagDelete} = toggleDirectoryDeleteFlagCmd;
            ${k.leaderActions.directoryClearMarks} = clearDirectoryMarksCmd;
            ${k.leaderActions.directoryCopyPreview} = previewDirectoryCopyCmd;
            ${k.leaderActions.directoryCopyApply} = applyDirectoryCopyCmd;
            ${k.leaderActions.directoryMovePreview} = previewDirectoryMoveCmd;
            ${k.leaderActions.directoryMoveApply} = applyDirectoryMoveCmd;
            ${k.leaderActions.directorySymlinkPreview} = previewDirectorySymlinkCmd;
            ${k.leaderActions.directorySymlinkApply} = applyDirectorySymlinkCmd;
            ${k.leaderActions.directoryRelativeSymlinkPreview} = previewDirectoryRelativeSymlinkCmd;
            ${k.leaderActions.directoryRelativeSymlinkApply} = applyDirectoryRelativeSymlinkCmd;
            ${k.leaderActions.directoryTransformLowerPreview} = previewDirectoryLowerCmd;
            ${k.leaderActions.directoryTransformLowerApply} = applyDirectoryLowerCmd;
            ${k.leaderActions.directoryTransformUpperPreview} = previewDirectoryUpperCmd;
            ${k.leaderActions.directoryTransformUpperApply} = applyDirectoryUpperCmd;
            ${k.leaderActions.directorySubdirInsert} = insertDirectorySubdirCmd;
            ${k.leaderActions.directorySubdirCollapse} = collapseDirectorySubdirCmd;
            ${k.leaderActions.directorySubdirRefresh} = refreshDirectorySubdirCmd;
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
