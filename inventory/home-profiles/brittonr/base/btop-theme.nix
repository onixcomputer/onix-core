{ lib, config, ... }:
let
  c = config.colors;
  b = c.btop;
in
{
  options.btopTheme = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = ''
      # Theme: onix-tokyo-night
      # Generated from config.colors

      # Main bg
      theme[main_bg]="${c.term_bg}"

      # Main text color
      theme[main_fg]="${b.main_fg}"

      # Title color for boxes
      theme[title]="${b.main_fg}"

      # Highlight color for keyboard shortcuts
      theme[hi_fg]="${b.hi_fg}"

      # Background color of selected item in processes box
      theme[selected_bg]="${b.selected_bg}"

      # Foreground color of selected item in processes box
      theme[selected_fg]="${b.main_fg}"

      # Color of inactive/disabled text
      theme[inactive_fg]="${b.inactive_fg}"

      # Misc colors for processes box including mini cpu graphs, details memory graph and details status text
      theme[proc_misc]="${b.hi_fg}"

      # Cpu box outline color
      theme[cpu_box]="${b.inactive_fg}"

      # Memory/disks box outline color
      theme[mem_box]="${b.inactive_fg}"

      # Net up/down box outline color
      theme[net_box]="${b.inactive_fg}"

      # Processes box outline color
      theme[proc_box]="${b.inactive_fg}"

      # Box divider line and small boxes line color
      theme[div_line]="${b.inactive_fg}"

      # Temperature graph colors
      theme[temp_start]="${c.term_green}"
      theme[temp_mid]="${c.term_yellow}"
      theme[temp_end]="${c.term_red}"

      # CPU graph colors
      theme[cpu_start]="${c.term_green}"
      theme[cpu_mid]="${c.term_yellow}"
      theme[cpu_end]="${c.term_red}"

      # Mem/Disk free meter
      theme[free_start]="${c.term_green}"
      theme[free_mid]="${c.term_yellow}"
      theme[free_end]="${c.term_red}"

      # Mem/Disk cached meter
      theme[cached_start]="${c.term_green}"
      theme[cached_mid]="${c.term_yellow}"
      theme[cached_end]="${c.term_red}"

      # Mem/Disk available meter
      theme[available_start]="${c.term_green}"
      theme[available_mid]="${c.term_yellow}"
      theme[available_end]="${c.term_red}"

      # Mem/Disk used meter
      theme[used_start]="${c.term_green}"
      theme[used_mid]="${c.term_yellow}"
      theme[used_end]="${c.term_red}"

      # Download graph colors
      theme[download_start]="${c.term_green}"
      theme[download_mid]="${c.term_yellow}"
      theme[download_end]="${c.term_red}"

      # Upload graph colors
      theme[upload_start]="${c.term_green}"
      theme[upload_mid]="${c.term_yellow}"
      theme[upload_end]="${c.term_red}"
    '';
    description = "btop theme text generated from config.colors";
  };
}
