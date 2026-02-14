{ lib, ... }:
{
  options.helixZenTheme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      dark = {
        # Deep, comfortable background
        "ui.background" = {
          bg = "#1c1c1c";
        };
        "ui.text" = {
          fg = "#d4d4d4";
        };

        # Minimal, muted statusline
        "ui.statusline" = {
          bg = "#2a2a2a";
          fg = "#888888";
        };
        "ui.statusline.insert" = {
          bg = "#3a5a3a";
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
          bg = "#7a9ec2";
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

        # Very subtle line numbers
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
          fg = "#7a9ec2";
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
          fg = "#7ab4c2";
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
          fg = "#6a9a6a";
        };
        "markup.list.unchecked" = {
          fg = "#9a6a6a";
        };

        "markup.quote" = {
          fg = "#888899";
          modifiers = [ "italic" ];
        };

        "markup.raw" = {
          fg = "#9ab48a";
        };
        "markup.raw.block" = {
          fg = "#9ab48a";
        };
        "markup.raw.inline" = {
          fg = "#9ab48a";
        };

        # Code block syntax
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

        # Diagnostics
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

        # Diff indicators
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

      light = {
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
    description = "Helix zen mode theme colors for distraction-free prose writing";
  };
}
