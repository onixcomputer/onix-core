{ config, lib, ... }:
let
  theme = config.theme.colors;
  # Remove # from hex colors for btop
  c = color: lib.removePrefix "#" color;
in
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "custom-theme";
      theme_background = false;
      vim_keys = true;
      cpu_sensor = "k10temp/Tctl";
      update_ms = 1000;
    };
  };

  # Dynamic theme based on active theme selection
  xdg.configFile."btop/themes/custom-theme.theme".text = ''
    # Theme: ${theme.name}
    # Dynamically generated from theme system

    # Main bg
    theme[main_bg]="#${c theme.bg}"

    # Main text color
    theme[main_fg]="#${c theme.fg}"

    # Title color for boxes
    theme[title]="#${c theme.fg}"

    # Highlight color for keyboard shortcuts
    theme[hi_fg]="#${c theme.accent}"

    # Background color of selected item in processes box
    theme[selected_bg]="#${c theme.bg_highlight}"

    # Foreground color of selected item in processes box
    theme[selected_fg]="#${c theme.fg}"

    # Color of inactive/disabled text
    theme[inactive_fg]="#${c theme.fg_dim}"

    # Misc colors for processes box including mini cpu graphs, details memory graph and details status text
    theme[proc_misc]="#${c theme.cyan}"

    # Cpu box outline color
    theme[cpu_box]="#${c theme.border}"

    # Memory/disks box outline color
    theme[mem_box]="#${c theme.border}"

    # Net up/down box outline color
    theme[net_box]="#${c theme.border}"

    # Processes box outline color
    theme[proc_box]="#${c theme.border}"

    # Box divider line and small boxes line color
    theme[div_line]="#${c theme.border}"

    # Temperature graph colors
    theme[temp_start]="#${c theme.green}"
    theme[temp_mid]="#${c theme.yellow}"
    theme[temp_end]="#${c theme.red}"

    # CPU graph colors
    theme[cpu_start]="#${c theme.green}"
    theme[cpu_mid]="#${c theme.yellow}"
    theme[cpu_end]="#${c theme.red}"

    # Mem/Disk free meter
    theme[free_start]="#${c theme.green}"
    theme[free_mid]="#${c theme.yellow}"
    theme[free_end]="#${c theme.red}"

    # Mem/Disk cached meter
    theme[cached_start]="#${c theme.green}"
    theme[cached_mid]="#${c theme.yellow}"
    theme[cached_end]="#${c theme.red}"

    # Mem/Disk available meter
    theme[available_start]="#${c theme.green}"
    theme[available_mid]="#${c theme.yellow}"
    theme[available_end]="#${c theme.red}"

    # Mem/Disk used meter
    theme[used_start]="#${c theme.green}"
    theme[used_mid]="#${c theme.yellow}"
    theme[used_end]="#${c theme.red}"

    # Download graph colors
    theme[download_start]="#${c theme.green}"
    theme[download_mid]="#${c theme.yellow}"
    theme[download_end]="#${c theme.red}"

    # Upload graph colors
    theme[upload_start]="#${c theme.green}"
    theme[upload_mid]="#${c theme.yellow}"
    theme[upload_end]="#${c theme.red}"
  '';
}
