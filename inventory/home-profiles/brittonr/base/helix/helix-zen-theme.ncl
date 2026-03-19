# Helix zen mode theme — distraction-free prose writing.
#
# Takes { dark, light } with pre-flattened .hex strings.
# Nix extracts zen.dark/zen.light, maps each field to .hex,
# then passes the flat records here.
fun args =>
  let d = args.dark in
  let l = args.light in
  {
    dark = {
      "ui.background" = { bg = d.bg },
      "ui.text" = { fg = d.fg },

      "ui.statusline" = { bg = d.bg_elevated, fg = d.fg_muted },
      "ui.statusline.insert" = { bg = d.statusline_insert_bg, fg = d.fg },
      "ui.statusline.select" = { bg = d.statusline_select_bg, fg = d.fg },
      "ui.statusline.inactive" = { bg = d.bg, fg = d.fg_inactive },

      "ui.cursor" = { bg = d.cursor },
      "ui.cursor.primary" = { bg = d.cursor_primary },
      "ui.cursor.match" = { bg = d.cursor_match },

      "ui.selection" = { bg = d.selection },
      "ui.selection.primary" = { bg = d.selection_primary },

      "ui.menu" = { bg = d.bg_surface, fg = d.fg },
      "ui.menu.selected" = { bg = d.menu_selected_bg, fg = d.menu_selected_fg },
      "ui.popup" = { bg = d.bg_surface, fg = d.fg },

      "ui.linenr" = { fg = d.fg_linenr },
      "ui.linenr.selected" = { fg = d.fg_linenr_selected },

      "ui.virtual" = { fg = d.fg_inactive },
      "ui.virtual.inlay-hint" = { fg = d.fg_inactive, modifiers = ["italic"] },
      "ui.virtual.ruler" = { bg = d.bg_elevated },
      "ui.cursorline.primary" = { bg = d.bg_surface },

      "markup.heading" = { fg = d.heading, modifiers = ["bold"] },
      "markup.heading.1" = { fg = d.heading1, modifiers = ["bold"] },
      "markup.heading.2" = { fg = d.heading, modifiers = ["bold"] },
      "markup.heading.3" = { fg = d.heading3, modifiers = ["bold"] },
      "markup.heading.marker" = { fg = d.fg_inactive },

      "markup.bold" = { fg = d.fg, modifiers = ["bold"] },
      "markup.italic" = { fg = d.italic, modifiers = ["italic"] },
      "markup.strikethrough" = { fg = d.fg_muted, modifiers = ["crossed_out"] },

      "markup.link" = { fg = d.link },
      "markup.link.url" = { fg = d.link_url, modifiers = ["underlined"] },
      "markup.link.text" = { fg = d.link },

      "markup.list" = { fg = d.fg_muted },
      "markup.list.checked" = { fg = d.list_checked },
      "markup.list.unchecked" = { fg = d.list_unchecked },

      "markup.quote" = { fg = d.quote, modifiers = ["italic"] },

      "markup.raw" = { fg = d.raw },
      "markup.raw.block" = { fg = d.raw },
      "markup.raw.inline" = { fg = d.raw },

      keyword = { fg = d.keyword },
      function = { fg = d.cursor_primary },
      type = { fg = d.type },
      string = { fg = d.type },
      comment = { fg = d.fg_linenr_selected, modifiers = ["italic"] },
      variable = { fg = d.variable },
      constant = { fg = d.constant },
      operator = { fg = d.fg_muted },
      punctuation = { fg = d.fg_punctuation },

      "diagnostic.hint" = { underline = { color = d.diag_hint, style = "dotted" } },
      "diagnostic.info" = { underline = { color = d.diag_info, style = "dotted" } },
      "diagnostic.warning" = { underline = { color = d.diag_warning, style = "curl" } },
      "diagnostic.error" = { underline = { color = d.diag_error, style = "curl" } },

      "diff.plus" = { fg = d.diff_plus },
      "diff.minus" = { fg = d.diff_minus },
      "diff.delta" = { fg = d.diff_delta },
    },

    light = {
      "ui.background" = { bg = l.bg },
      "ui.text" = { fg = l.fg },

      "ui.statusline" = { bg = l.bg_elevated, fg = l.fg_muted },
      "ui.statusline.insert" = { bg = l.statusline_insert_bg, fg = l.fg },
      "ui.statusline.select" = { bg = l.statusline_select_bg, fg = l.fg },
      "ui.statusline.inactive" = { bg = l.bg_surface, fg = l.fg_inactive },

      "ui.cursor" = { bg = l.cursor },
      "ui.cursor.primary" = { bg = l.cursor_primary },
      "ui.selection" = { bg = l.selection },

      "ui.menu" = { bg = l.bg_surface, fg = l.fg },
      "ui.menu.selected" = { bg = l.menu_selected_bg, fg = l.menu_selected_fg },
      "ui.popup" = { bg = l.bg_surface, fg = l.fg },

      "ui.linenr" = { fg = l.fg_linenr },
      "ui.linenr.selected" = { fg = l.fg_linenr_selected },
      "ui.virtual" = { fg = l.fg_virtual },
      "ui.virtual.ruler" = { bg = l.bg_elevated },
      "ui.cursorline.primary" = { bg = l.bg_surface },

      "markup.heading" = { fg = l.heading, modifiers = ["bold"] },
      "markup.bold" = { fg = l.fg, modifiers = ["bold"] },
      "markup.italic" = { fg = l.italic, modifiers = ["italic"] },
      "markup.link" = { fg = l.link },
      "markup.link.url" = { fg = l.link_url, modifiers = ["underlined"] },
      "markup.list" = { fg = l.fg_muted },
      "markup.quote" = { fg = l.quote, modifiers = ["italic"] },
      "markup.raw" = { fg = l.raw },

      keyword = { fg = l.keyword },
      function = { fg = l.heading },
      string = { fg = l.raw },
      comment = { fg = l.comment, modifiers = ["italic"] },

      "diagnostic.hint" = { underline = { color = l.diag_hint, style = "dotted" } },
      "diagnostic.warning" = { underline = { color = l.diag_warning, style = "curl" } },
      "diagnostic.error" = { underline = { color = l.diag_error, style = "curl" } },

      "diff.plus" = { fg = l.diff_plus },
      "diff.minus" = { fg = l.diff_minus },
      "diff.delta" = { fg = l.diff_delta },
    },
  }
