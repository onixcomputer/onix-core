{
  inputs,
  pkgs,
  config,
  ...
}:
let
  k = config.keymap;
  nixfmt-rs = inputs.nixfmt-rs.packages.${pkgs.stdenv.hostPlatform.system}.default;

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

      package = pkgs.lib.mkForce pkgs.steelix;

      preHook = helixThemeOverlay;

      extraPackages = with pkgs; [
        steel
        steel-language-server
        cargo
        rustc
        clippy
        rustfmt
        rust-analyzer
        nls
        taplo
        yaml-language-server
        vscode-langservers-extracted
        bash-language-server
        shfmt
        prettier
        ltex-ls
        libxml2
        lemminx
      ];

      settings = {
        theme = "noctalia";
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
          };
        };
      };
      languages.language = [
        {
          name = "nix";
          auto-format = true;
          formatter.command = "${nixfmt-rs}/bin/nixfmt";
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
          name = "toml";
          auto-format = true;
          formatter.command = "${pkgs.taplo}/bin/taplo";
          formatter.args = [
            "fmt"
            "-"
          ];
          language-servers = [ "taplo" ];
        }
        {
          name = "yaml";
          auto-format = false;
          formatter.command = "${pkgs.prettier}/bin/prettier";
          formatter.args = [
            "--parser"
            "yaml"
          ];
          language-servers = [ "yaml-language-server" ];
        }
        {
          name = "json";
          auto-format = false;
          formatter.command = "${pkgs.prettier}/bin/prettier";
          formatter.args = [
            "--parser"
            "json"
          ];
          language-servers = [ "vscode-json-language-server" ];
        }
        {
          name = "bash";
          auto-format = true;
          formatter.command = "${pkgs.shfmt}/bin/shfmt";
          formatter.args = [
            "-i"
            "2"
            "-ci"
          ];
          language-servers = [ "bash-language-server" ];
        }
        {
          name = "asciidoc";
          scope = "source.asciidoc";
          file-types = [
            "adoc"
            "asciidoc"
          ];
          auto-format = false;
          language-servers = [ "ltex-ls" ];
        }
        {
          name = "xml";
          auto-format = true;
          formatter.command = "${pkgs.libxml2}/bin/xmllint";
          formatter.args = [
            "--format"
            "-"
          ];
          language-servers = [ "lemminx" ];
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
        {
          name = "scheme";
          auto-format = false;
          language-servers = [ "steel-language-server" ];
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
        taplo = {
          command = "${pkgs.taplo}/bin/taplo";
          args = [
            "lsp"
            "stdio"
          ];
        };
        yaml-language-server = {
          command = "${pkgs.yaml-language-server}/bin/yaml-language-server";
          args = [ "--stdio" ];
        };
        vscode-json-language-server = {
          command = "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server";
          args = [ "--stdio" ];
        };
        bash-language-server = {
          command = "${pkgs.bash-language-server}/bin/bash-language-server";
          args = [ "start" ];
        };
        ltex-ls = {
          command = "${pkgs.ltex-ls}/bin/ltex-ls";
        };
        lemminx = {
          command = "${pkgs.lemminx}/bin/lemminx";
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
        steel-language-server = {
          command = "${pkgs.steel-language-server}/bin/steel-language-server";
        };
      };

      # Runtime theme owned by Noctalia: its built-in helix template writes
      # ~/.config/helix/themes/noctalia.toml with the current scheme on every
      # color change, and the theme overlay links that mutable file over this
      # immutable seed. The Noctalia mode hook sends SIGUSR1 to running helix
      # processes, which triggers a live config + theme reload (helix handles
      # SIGUSR1 by refreshing its configuration).
      themes."noctalia" = config.helixTheme.dark;
    }).wrapper
  ];

  home.sessionVariables.EDITOR = "hx";
}
