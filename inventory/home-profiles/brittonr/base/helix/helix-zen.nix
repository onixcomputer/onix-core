# Helix Zen Mode - Distraction-free prose/markdown editor
# A separate helix wrapper optimized for writing documentation and prose
# Based on: https://helix-editor-tutorials.com/tutorials/writing-documentation-and-prose-in-markdown-using-helix/
{
  inputs,
  pkgs,
  config,
  ...
}:
let
  k = config.keymap;
  ed = config.editor;

  # Build the full helix-zen wrapper
  helixZenWrapper = inputs.wrappers.wrapperModules.helix.apply {
    inherit pkgs;

    # Provide the binary as 'zen' to differentiate from regular helix
    binName = "zen";

    extraPackages = with pkgs; [
      # Markdown language servers
      marksman # Markdown LSP for navigation and completion
      ltex-ls-plus # Grammar and spell checking (LanguageTool-based)
      harper # Fast Rust-based grammar checker

      # Formatters
      nodePackages.prettier # Markdown formatting with prose-wrap control

      # Preview
      glow # Terminal markdown renderer
    ];

    settings = {
      theme = "zen-dark";

      editor = {
        # Minimal, distraction-free cursor
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        # Zen mode: use line-numbers gutter for centering
        # Toggle with space+t+z to switch between zen (centered) and normal mode
        gutters = {
          layout = [
            "diagnostics"
            "line-numbers"
            "spacer"
            "diff"
          ];
          line-numbers.min-width = 1;
        };

        # Soft wrapping enabled globally - essential for prose
        soft-wrap = {
          enable = true;
          max-wrap = ed.softWrap.maxWrap;
          max-indent-retain = 0;
          wrap-indicator = ""; # No indicator for clean prose appearance
          wrap-at-text-width = true;
        };

        # Clean statusline for writing
        statusline = {
          left = [
            "mode"
            "spinner"
          ];
          center = [ "file-name" ];
          right = [
            "diagnostics"
            "position"
            "file-type"
          ];
          separator = " ";
        };

        # Hide distractions
        bufferline = "never";
        true-color = true;
        color-modes = true;
        mouse = true;

        # Inline diagnostics for grammar/spelling feedback
        inline-diagnostics = {
          cursor-line = "hint";
          other-lines = "disable";
          prefix-len = ed.inlineDiagnostics.prefixLen;
          max-wrap = ed.softWrap.maxWrapZen;
          max-diagnostics = ed.inlineDiagnostics.maxCount;
        };

        # Indent guides off for cleaner prose
        indent-guides.render = false;

        # Visual aids for prose
        cursorline = true;
        inherit (ed) rulers;

        # Auto-save for writing flow
        auto-save = {
          focus-lost = true;
          after-delay = {
            enable = true;
            inherit (ed.autoSave) timeout;
          };
        };

        # Search configuration
        search = {
          smart-case = true;
          wrap-around = true;
        };
      };

      keys.normal = {
        ${k.leader} = {
          ${k.leaderActions.filePicker} = "file_picker";
          ${k.leaderActions.save} = ":w";
          ${k.leaderActions.quit} = ":q";

          # Zen mode toggles under leader+t
          t = {
            z = ":toggle gutters.line-numbers.min-width 40 1";
            s = ":toggle soft-wrap.enable";
            d = '':toggle inline-diagnostics.cursor-line "hint" "disable"'';
            g = '':toggle inline-diagnostics.other-lines "hint" "disable"'';
            w = ":toggle whitespace.render all none";
          };

          ${k.leaderActions.format} = ":format";

          p = [
            ":write"
            ":sh env -i HOME=$HOME PATH=$PATH TERM=$TERM glow -p '%{buffer_name}'"
          ];

          "?" =
            ":echo 'ZEN KEYS: space+p=preview | space+f=format | space+t+z=zen-center | space+t+s=soft-wrap | space+t+d=diagnostics | space+t+g=grammar | space+t+w=whitespace | Alt+hjkl=insert-nav'";
        };
      };

      keys.insert = {
        "A-${k.nav.left}" = "move_char_left";
        "A-${k.nav.down}" = "move_visual_line_down";
        "A-${k.nav.up}" = "move_visual_line_up";
        "A-${k.nav.right}" = "move_char_right";
        "A-${k.word.forward}" = "move_next_word_start";
        "A-${k.word.backward}" = "move_prev_word_start";
      };
    };

    languages.language = [
      {
        name = "markdown";
        auto-format = true;
        soft-wrap = {
          enable = true;
          wrap-at-text-width = true;
        };
        language-servers = [
          "marksman"
          "harper"
          "ltex-ls-plus"
        ];
        formatter = {
          command = "${pkgs.nodePackages.prettier}/bin/prettier";
          args = [
            "--parser"
            "markdown"
            "--prose-wrap"
            "never" # Preserve single-line paragraphs for git diffs
          ];
        };
        # List continuation tokens for markdown
        comment-tokens = [
          "-"
          "+"
          "*"
          "- [ ]"
          ">"
        ];
        text-width = ed.textWidth;
      }
      {
        # Plain text files with grammar checking
        name = "text";
        scope = "text.plain";
        file-types = [ "txt" ];
        soft-wrap = {
          enable = true;
          wrap-at-text-width = true;
        };
        language-servers = [ "ltex-ls-plus" ];
        text-width = ed.textWidth;
      }
    ];

    languages.language-server = {
      marksman = {
        command = "${pkgs.marksman}/bin/marksman";
        args = [ "server" ];
      };
      harper = {
        command = "${pkgs.harper}/bin/harper-ls";
        args = [ "--stdio" ];
      };
      ltex-ls-plus = {
        command = "${pkgs.ltex-ls-plus}/bin/ltex-ls-plus";
        config = {
          ltex = {
            language = "en-US";
            diagnosticSeverity = "hint";
            "ltex-ls".logLevel = "warning";

            # Spelling is now enabled (removed MORFOLOGIK_RULE_EN_US)
            disabledRules = {
              "en-US" = [ "PROFANITY" ];
              "en-GB" = [ "PROFANITY" ];
            };

            # Enable style rules for better prose
            enabledRules = {
              "en-US" = [
                "PASSIVE_VOICE"
                "TOO_LONG_SENTENCE"
              ];
            };

            # Custom dictionary for tech terms
            dictionary = {
              "en-US" = [
                "NixOS"
                "Nix"
                "flake"
                "nixpkgs"
                "derivation"
                "home-manager"
                "systemd"
                "Helix"
                "LSP"
                "treesitter"
                "config"
                "dotfiles"
                "CLI"
                "API"
                "JSON"
                "TOML"
                "YAML"
                "async"
                "struct"
                "enum"
              ];
              "en-GB" = [ "builtin" ];
            };

            # Ignore code blocks in markdown
            markdown.nodes = {
              CodeBlock = "ignore";
              FencedCodeBlock = "ignore";
              IndentedCodeBlock = "ignore";
              Code = "ignore";
            };

            additionalRules.enablePickyRules = false;
          };
        };
      };
    };

    themes.zen-dark = config.helixZenTheme.dark;

    themes.zen-light = config.helixZenTheme.light;
  };

  # Extract only the zen binary to avoid collision with main helix wrapper
  zenOnly = pkgs.runCommand "zen" { } ''
    mkdir -p $out/bin
    ln -s ${helixZenWrapper.wrapper}/bin/zen $out/bin/zen
  '';
in
{
  home.packages = [ zenOnly ];
}
