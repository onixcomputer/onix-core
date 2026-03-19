{ lib, config, ... }:
let
  c = config.theme.data;
  d = c.zen.dark;
  l = c.zen.light;
in
{
  options.helixZenTheme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      dark = {
        "ui.background".bg = d.bg.hex;
        "ui.text".fg = d.fg.hex;

        "ui.statusline" = {
          bg = d.bg_elevated.hex;
          fg = d.fg_muted.hex;
        };
        "ui.statusline.insert" = {
          bg = d.statusline_insert_bg.hex;
          fg = d.fg.hex;
        };
        "ui.statusline.select" = {
          bg = d.statusline_select_bg.hex;
          fg = d.fg.hex;
        };
        "ui.statusline.inactive" = {
          bg = d.bg.hex;
          fg = d.fg_inactive.hex;
        };

        "ui.cursor".bg = d.cursor.hex;
        "ui.cursor.primary".bg = d.cursor_primary.hex;
        "ui.cursor.match".bg = d.cursor_match.hex;

        "ui.selection".bg = d.selection.hex;
        "ui.selection.primary".bg = d.selection_primary.hex;

        "ui.menu" = {
          bg = d.bg_surface.hex;
          fg = d.fg.hex;
        };
        "ui.menu.selected" = {
          bg = d.menu_selected_bg.hex;
          fg = d.menu_selected_fg.hex;
        };
        "ui.popup" = {
          bg = d.bg_surface.hex;
          fg = d.fg.hex;
        };

        "ui.linenr".fg = d.fg_linenr.hex;
        "ui.linenr.selected".fg = d.fg_linenr_selected.hex;

        "ui.virtual".fg = d.fg_inactive.hex;
        "ui.virtual.inlay-hint" = {
          fg = d.fg_inactive.hex;
          modifiers = [ "italic" ];
        };
        "ui.virtual.ruler".bg = d.bg_elevated.hex;
        "ui.cursorline.primary".bg = d.bg_surface.hex;

        "markup.heading" = {
          fg = d.heading.hex;
          modifiers = [ "bold" ];
        };
        "markup.heading.1" = {
          fg = d.heading1.hex;
          modifiers = [ "bold" ];
        };
        "markup.heading.2" = {
          fg = d.heading.hex;
          modifiers = [ "bold" ];
        };
        "markup.heading.3" = {
          fg = d.heading3.hex;
          modifiers = [ "bold" ];
        };
        "markup.heading.marker".fg = d.fg_inactive.hex;

        "markup.bold" = {
          fg = d.fg.hex;
          modifiers = [ "bold" ];
        };
        "markup.italic" = {
          fg = d.italic.hex;
          modifiers = [ "italic" ];
        };
        "markup.strikethrough" = {
          fg = d.fg_muted.hex;
          modifiers = [ "crossed_out" ];
        };

        "markup.link".fg = d.link.hex;
        "markup.link.url" = {
          fg = d.link_url.hex;
          modifiers = [ "underlined" ];
        };
        "markup.link.text".fg = d.link.hex;

        "markup.list".fg = d.fg_muted.hex;
        "markup.list.checked".fg = d.list_checked.hex;
        "markup.list.unchecked".fg = d.list_unchecked.hex;

        "markup.quote" = {
          fg = d.quote.hex;
          modifiers = [ "italic" ];
        };

        "markup.raw".fg = d.raw.hex;
        "markup.raw.block".fg = d.raw.hex;
        "markup.raw.inline".fg = d.raw.hex;

        "keyword".fg = d.keyword.hex;
        "function".fg = d.cursor_primary.hex;
        "type".fg = d.type.hex;
        "string".fg = d.type.hex;
        "comment" = {
          fg = d.fg_linenr_selected.hex;
          modifiers = [ "italic" ];
        };
        "variable".fg = d.variable.hex;
        "constant".fg = d.constant.hex;
        "operator".fg = d.fg_muted.hex;
        "punctuation".fg = d.fg_punctuation.hex;

        "diagnostic.hint".underline = {
          color = d.diag_hint.hex;
          style = "dotted";
        };
        "diagnostic.info".underline = {
          color = d.diag_info.hex;
          style = "dotted";
        };
        "diagnostic.warning".underline = {
          color = d.diag_warning.hex;
          style = "curl";
        };
        "diagnostic.error".underline = {
          color = d.diag_error.hex;
          style = "curl";
        };

        "diff.plus".fg = d.diff_plus.hex;
        "diff.minus".fg = d.diff_minus.hex;
        "diff.delta".fg = d.diff_delta.hex;
      };

      light = {
        "ui.background".bg = l.bg.hex;
        "ui.text".fg = l.fg.hex;

        "ui.statusline" = {
          bg = l.bg_elevated.hex;
          fg = l.fg_muted.hex;
        };
        "ui.statusline.insert" = {
          bg = l.statusline_insert_bg.hex;
          fg = l.fg.hex;
        };
        "ui.statusline.select" = {
          bg = l.statusline_select_bg.hex;
          fg = l.fg.hex;
        };
        "ui.statusline.inactive" = {
          bg = l.bg_surface.hex;
          fg = l.fg_inactive.hex;
        };

        "ui.cursor".bg = l.cursor.hex;
        "ui.cursor.primary".bg = l.cursor_primary.hex;
        "ui.selection".bg = l.selection.hex;

        "ui.menu" = {
          bg = l.bg_surface.hex;
          fg = l.fg.hex;
        };
        "ui.menu.selected" = {
          bg = l.menu_selected_bg.hex;
          fg = l.menu_selected_fg.hex;
        };
        "ui.popup" = {
          bg = l.bg_surface.hex;
          fg = l.fg.hex;
        };

        "ui.linenr".fg = l.fg_linenr.hex;
        "ui.linenr.selected".fg = l.fg_linenr_selected.hex;
        "ui.virtual".fg = l.fg_virtual.hex;
        "ui.virtual.ruler".bg = l.bg_elevated.hex;
        "ui.cursorline.primary".bg = l.bg_surface.hex;

        "markup.heading" = {
          fg = l.heading.hex;
          modifiers = [ "bold" ];
        };
        "markup.bold" = {
          fg = l.fg.hex;
          modifiers = [ "bold" ];
        };
        "markup.italic" = {
          fg = l.italic.hex;
          modifiers = [ "italic" ];
        };
        "markup.link".fg = l.link.hex;
        "markup.link.url" = {
          fg = l.link_url.hex;
          modifiers = [ "underlined" ];
        };
        "markup.list".fg = l.fg_muted.hex;
        "markup.quote" = {
          fg = l.quote.hex;
          modifiers = [ "italic" ];
        };
        "markup.raw".fg = l.raw.hex;

        "keyword".fg = l.keyword.hex;
        "function".fg = l.heading.hex;
        "string".fg = l.raw.hex;
        "comment" = {
          fg = l.comment.hex;
          modifiers = [ "italic" ];
        };

        "diagnostic.hint".underline = {
          color = l.diag_hint.hex;
          style = "dotted";
        };
        "diagnostic.warning".underline = {
          color = l.diag_warning.hex;
          style = "curl";
        };
        "diagnostic.error".underline = {
          color = l.diag_error.hex;
          style = "curl";
        };

        "diff.plus".fg = l.diff_plus.hex;
        "diff.minus".fg = l.diff_minus.hex;
        "diff.delta".fg = l.diff_delta.hex;
      };
    };
    description = "Helix zen mode theme colors for distraction-free prose writing";
  };
}
