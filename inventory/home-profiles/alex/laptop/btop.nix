{ config, ... }:
let
  theme = config.theme.colors;
in
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "tokyo-night";
      theme_background = false;
      vim_keys = true;
    };
  };

  xdg.configFile."btop/themes/tokyo-night.theme".text = ''
    # Theme: tokyo-night

    # Main bg
    theme[main_bg]="${theme.bg}"

    # Main text color
    theme[main_fg]="${theme.fg}"

    # Title color for boxes
    theme[title]="${theme.fg}"

    # Highlight color for keyboard shortcuts
    theme[hi_fg]="${theme.cyan}"

    # Background color of selected item in processes box
    theme[selected_bg]="${theme.bg_highlight}"

    # Foreground color of selected item in processes box
    theme[selected_fg]="${theme.fg}"

    # Color of inactive/disabled text
    theme[inactive_fg]="${theme.border}"

    # Misc colors for processes box including mini cpu graphs, details memory graph and details status text
    theme[proc_misc]="${theme.cyan}"

    # Cpu box outline color
    theme[cpu_box]="${theme.border}"

    # Memory/disks box outline color
    theme[mem_box]="${theme.border}"

    # Net up/down box outline color
    theme[net_box]="${theme.border}"

    # Processes box outline color
    theme[proc_box]="${theme.border}"

    # Box divider line and small boxes line color
    theme[div_line]="${theme.border}"

    # Temperature graph colors
    theme[temp_start]="${theme.green}"
    theme[temp_mid]="${theme.yellow}"
    theme[temp_end]="${theme.red}"

    # CPU graph colors
    theme[cpu_start]="${theme.green}"
    theme[cpu_mid]="${theme.yellow}"
    theme[cpu_end]="${theme.red}"

    # Mem/Disk free meter
    theme[free_start]="${theme.green}"
    theme[free_mid]="${theme.yellow}"
    theme[free_end]="${theme.red}"

    # Mem/Disk cached meter
    theme[cached_start]="${theme.green}"
    theme[cached_mid]="${theme.yellow}"
    theme[cached_end]="${theme.red}"

    # Mem/Disk available meter
    theme[available_start]="${theme.green}"
    theme[available_mid]="${theme.yellow}"
    theme[available_end]="${theme.red}"

    # Mem/Disk used meter
    theme[used_start]="${theme.green}"
    theme[used_mid]="${theme.yellow}"
    theme[used_end]="${theme.red}"

    # Download graph colors
    theme[download_start]="${theme.green}"
    theme[download_mid]="${theme.yellow}"
    theme[download_end]="${theme.red}"

    # Upload graph colors
    theme[upload_start]="${theme.green}"
    theme[upload_mid]="${theme.yellow}"
    theme[upload_end]="${theme.red}"
  '';
}
