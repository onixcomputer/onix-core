{ lib, config, ... }:
let
  c = config.theme.data;
  b = c.btop;
in
{
  options.btopTheme = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = ''
      # Theme: onix-tokyo-night
      # Generated from config.theme

      # Main bg
      theme[main_bg]="${c.term_bg.hex}"

      # Main text color
      theme[main_fg]="${b.main_fg.hex}"

      # Title color for boxes
      theme[title]="${b.main_fg.hex}"

      # Highlight color for keyboard shortcuts
      theme[hi_fg]="${b.hi_fg.hex}"

      # Background color of selected item in processes box
      theme[selected_bg]="${b.selected_bg.hex}"

      # Foreground color of selected item in processes box
      theme[selected_fg]="${b.main_fg.hex}"

      # Color of inactive/disabled text
      theme[inactive_fg]="${b.inactive_fg.hex}"

      # Misc colors for processes box including mini cpu graphs, details memory graph and details status text
      theme[proc_misc]="${b.hi_fg.hex}"

      # Cpu box outline color
      theme[cpu_box]="${b.inactive_fg.hex}"

      # Memory/disks box outline color
      theme[mem_box]="${b.inactive_fg.hex}"

      # Net up/down box outline color
      theme[net_box]="${b.inactive_fg.hex}"

      # Processes box outline color
      theme[proc_box]="${b.inactive_fg.hex}"

      # Box divider line and small boxes line color
      theme[div_line]="${b.inactive_fg.hex}"

      # Temperature graph colors
      theme[temp_start]="${c.term_green.hex}"
      theme[temp_mid]="${c.term_yellow.hex}"
      theme[temp_end]="${c.term_red.hex}"

      # CPU graph colors
      theme[cpu_start]="${c.term_green.hex}"
      theme[cpu_mid]="${c.term_yellow.hex}"
      theme[cpu_end]="${c.term_red.hex}"

      # Mem/Disk free meter
      theme[free_start]="${c.term_green.hex}"
      theme[free_mid]="${c.term_yellow.hex}"
      theme[free_end]="${c.term_red.hex}"

      # Mem/Disk cached meter
      theme[cached_start]="${c.term_green.hex}"
      theme[cached_mid]="${c.term_yellow.hex}"
      theme[cached_end]="${c.term_red.hex}"

      # Mem/Disk available meter
      theme[available_start]="${c.term_green.hex}"
      theme[available_mid]="${c.term_yellow.hex}"
      theme[available_end]="${c.term_red.hex}"

      # Mem/Disk used meter
      theme[used_start]="${c.term_green.hex}"
      theme[used_mid]="${c.term_yellow.hex}"
      theme[used_end]="${c.term_red.hex}"

      # Download graph colors
      theme[download_start]="${c.term_green.hex}"
      theme[download_mid]="${c.term_yellow.hex}"
      theme[download_end]="${c.term_red.hex}"

      # Upload graph colors
      theme[upload_start]="${c.term_green.hex}"
      theme[upload_mid]="${c.term_yellow.hex}"
      theme[upload_end]="${c.term_red.hex}"
    '';
    description = "btop theme text generated from config.theme";
  };
}
