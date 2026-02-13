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
          max-wrap = 25;
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
          prefix-len = 2;
          max-wrap = 40;
          max-diagnostics = 5;
        };

        # Indent guides off for cleaner prose
        indent-guides.render = false;

        # Visual aids for prose
        cursorline = true;
        rulers = [ 80 ];

        # Auto-save for writing flow
        auto-save = {
          focus-lost = true;
          after-delay = {
            enable = true;
            timeout = 3000;
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
        # 80 chars text width for prose
        text-width = 80;
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
        text-width = 80;
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

    # Zen theme: Minimal, muted colors optimized for prose readability
    themes.zen-dark = {
      # Deep, comfortable background
      "ui.background" = {
        bg = "#1c1c1c";
      };
      "ui.text" = {
        fg = "#d4d4d4"; # Soft white, easy on eyes
      };

      # Minimal, muted statusline
      "ui.statusline" = {
        bg = "#2a2a2a";
        fg = "#888888";
      };
      "ui.statusline.insert" = {
        bg = "#3a5a3a"; # Muted green
        fg = "#d4d4d4";
      };
      "ui.statusline.select" = {
        bg = "#4a4a5a";
        fg = "#d4d4d4";
      };
      "ui.statusline.inactive" = {
        bg = "#1c1c1c";
        fg = "#555555";
      };

      # Subtle cursor
      "ui.cursor" = {
        bg = "#5a5a6a";
      };
      "ui.cursor.primary" = {
        bg = "#7a9ec2"; # Calm blue
      };
      "ui.cursor.match" = {
        bg = "#4a5a4a";
      };

      # Soft selection
      "ui.selection" = {
        bg = "#333344";
      };
      "ui.selection.primary" = {
        bg = "#3a3a4a";
      };

      # Menus
      "ui.menu" = {
        bg = "#252525";
        fg = "#d4d4d4";
      };
      "ui.menu.selected" = {
        bg = "#3a4a5a";
        fg = "#ffffff";
      };
      "ui.popup" = {
        bg = "#252525";
        fg = "#d4d4d4";
      };

      # Very subtle line numbers (when visible)
      "ui.linenr" = {
        fg = "#444444";
      };
      "ui.linenr.selected" = {
        fg = "#666666";
      };

      # Virtual text/inlay hints
      "ui.virtual" = {
        fg = "#555555";
      };
      "ui.virtual.inlay-hint" = {
        fg = "#555555";
        modifiers = [ "italic" ];
      };
      "ui.virtual.ruler" = {
        bg = "#2a2a2a";
      };

      # Cursorline
      "ui.cursorline.primary" = {
        bg = "#252525";
      };

      # Markdown-optimized syntax highlighting
      "markup.heading" = {
        fg = "#7a9ec2"; # Calm blue headers
        modifiers = [ "bold" ];
      };
      "markup.heading.1" = {
        fg = "#8ab4f8";
        modifiers = [ "bold" ];
      };
      "markup.heading.2" = {
        fg = "#7a9ec2";
        modifiers = [ "bold" ];
      };
      "markup.heading.3" = {
        fg = "#6a8eb2";
        modifiers = [ "bold" ];
      };
      "markup.heading.marker" = {
        fg = "#555555";
      };

      "markup.bold" = {
        fg = "#d4d4d4";
        modifiers = [ "bold" ];
      };
      "markup.italic" = {
        fg = "#b4c4d4";
        modifiers = [ "italic" ];
      };
      "markup.strikethrough" = {
        fg = "#888888";
        modifiers = [ "crossed_out" ];
      };

      "markup.link" = {
        fg = "#7ab4c2"; # Teal links
      };
      "markup.link.url" = {
        fg = "#5a8a9a";
        modifiers = [ "underlined" ];
      };
      "markup.link.text" = {
        fg = "#7ab4c2";
      };

      "markup.list" = {
        fg = "#888888";
      };
      "markup.list.checked" = {
        fg = "#6a9a6a"; # Green for completed
      };
      "markup.list.unchecked" = {
        fg = "#9a6a6a"; # Red-ish for incomplete
      };

      "markup.quote" = {
        fg = "#888899";
        modifiers = [ "italic" ];
      };

      "markup.raw" = {
        fg = "#9ab48a"; # Code blocks in muted green
      };
      "markup.raw.block" = {
        fg = "#9ab48a";
      };
      "markup.raw.inline" = {
        fg = "#9ab48a";
      };

      # Code block syntax (for embedded code in markdown)
      "keyword" = {
        fg = "#c49a6a";
      };
      "function" = {
        fg = "#7a9ec2";
      };
      "type" = {
        fg = "#8ab48a";
      };
      "string" = {
        fg = "#8ab48a";
      };
      "comment" = {
        fg = "#666666";
        modifiers = [ "italic" ];
      };
      "variable" = {
        fg = "#b4b4c4";
      };
      "constant" = {
        fg = "#c4a47a";
      };
      "operator" = {
        fg = "#888888";
      };
      "punctuation" = {
        fg = "#777777";
      };

      # Diagnostics (grammar/spelling)
      "diagnostic.hint" = {
        underline = {
          color = "#5a7a5a";
          style = "dotted";
        };
      };
      "diagnostic.info" = {
        underline = {
          color = "#5a7a9a";
          style = "dotted";
        };
      };
      "diagnostic.warning" = {
        underline = {
          color = "#9a8a5a";
          style = "curl";
        };
      };
      "diagnostic.error" = {
        underline = {
          color = "#9a5a5a";
          style = "curl";
        };
      };

      # Diff indicators (very subtle)
      "diff.plus" = {
        fg = "#5a8a5a";
      };
      "diff.minus" = {
        fg = "#8a5a5a";
      };
      "diff.delta" = {
        fg = "#7a7a5a";
      };
    };

    # Light theme variant for daytime writing
    themes.zen-light = {
      "ui.background" = {
        bg = "#fafafa";
      };
      "ui.text" = {
        fg = "#333333";
      };

      "ui.statusline" = {
        bg = "#e8e8e8";
        fg = "#666666";
      };
      "ui.statusline.insert" = {
        bg = "#d8e8d8";
        fg = "#333333";
      };
      "ui.statusline.select" = {
        bg = "#d8d8e8";
        fg = "#333333";
      };
      "ui.statusline.inactive" = {
        bg = "#f0f0f0";
        fg = "#aaaaaa";
      };

      "ui.cursor" = {
        bg = "#c0c0d0";
      };
      "ui.cursor.primary" = {
        bg = "#7090c0";
      };

      "ui.selection" = {
        bg = "#d0d8e8";
      };

      "ui.menu" = {
        bg = "#f0f0f0";
        fg = "#333333";
      };
      "ui.menu.selected" = {
        bg = "#c0d0e0";
        fg = "#111111";
      };
      "ui.popup" = {
        bg = "#f0f0f0";
        fg = "#333333";
      };

      "ui.linenr" = {
        fg = "#cccccc";
      };
      "ui.linenr.selected" = {
        fg = "#999999";
      };

      "ui.virtual" = {
        fg = "#bbbbbb";
      };
      "ui.virtual.ruler" = {
        bg = "#e8e8e8";
      };

      # Cursorline
      "ui.cursorline.primary" = {
        bg = "#f0f0f0";
      };

      "markup.heading" = {
        fg = "#2060a0";
        modifiers = [ "bold" ];
      };
      "markup.bold" = {
        fg = "#333333";
        modifiers = [ "bold" ];
      };
      "markup.italic" = {
        fg = "#444455";
        modifiers = [ "italic" ];
      };
      "markup.link" = {
        fg = "#206080";
      };
      "markup.link.url" = {
        fg = "#4080a0";
        modifiers = [ "underlined" ];
      };
      "markup.list" = {
        fg = "#666666";
      };
      "markup.quote" = {
        fg = "#666677";
        modifiers = [ "italic" ];
      };
      "markup.raw" = {
        fg = "#408040";
      };

      "keyword" = {
        fg = "#a06020";
      };
      "function" = {
        fg = "#2060a0";
      };
      "string" = {
        fg = "#408040";
      };
      "comment" = {
        fg = "#999999";
        modifiers = [ "italic" ];
      };

      "diagnostic.hint" = {
        underline = {
          color = "#60a060";
          style = "dotted";
        };
      };
      "diagnostic.warning" = {
        underline = {
          color = "#a0a060";
          style = "curl";
        };
      };
      "diagnostic.error" = {
        underline = {
          color = "#a06060";
          style = "curl";
        };
      };

      "diff.plus" = {
        fg = "#408040";
      };
      "diff.minus" = {
        fg = "#a04040";
      };
      "diff.delta" = {
        fg = "#808040";
      };
    };
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
