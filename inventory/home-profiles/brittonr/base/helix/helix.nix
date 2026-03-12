{
  inputs,
  pkgs,
  config,
  ...
}:
let
  k = config.keymap;
in
{
  home.packages = [
    (inputs.wrappers.wrapperModules.helix.apply {
      inherit pkgs;

      extraPackages = with pkgs; [
        cargo
        rustc
        clippy
        rustfmt
        rust-analyzer
        nls
      ];

      settings = {
        theme = "onix-dark";
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

      themes.onix-dark = config.helixTheme.dark;

      themes.onix-light = config.helixTheme.light;
    }).wrapper
  ];

  home.sessionVariables.EDITOR = "hx";
}
