{ config, lib, ... }:
let
  theme = config.theme.data;
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
    theme[main_bg]="#${c theme.bg.hex}"

    # Main text color
    theme[main_fg]="#${c theme.fg.hex}"

    # Title color for boxes
    theme[title]="#${c theme.fg.hex}"

    # Highlight color for keyboard shortcuts
    theme[hi_fg]="#${c theme.accent.hex}"

    # Background color of selected item in processes box
    theme[selected_bg]="#${c theme.bg_highlight.hex}"

    # Foreground color of selected item in processes box
    theme[selected_fg]="#${c theme.fg.hex}"

    # Color of inactive/disabled text
    theme[inactive_fg]="#${c theme.fg_dim.hex}"

    # Misc colors for processes box including mini cpu graphs, details memory graph and details status text
    theme[proc_misc]="#${c theme.cyan.hex}"

    # Cpu box outline color
    theme[cpu_box]="#${c theme.border.hex}"

    # Memory/disks box outline color
    theme[mem_box]="#${c theme.border.hex}"

    # Net up/down box outline color
    theme[net_box]="#${c theme.border.hex}"

    # Processes box outline color
    theme[proc_box]="#${c theme.border.hex}"

    # Box divider line and small boxes line color
    theme[div_line]="#${c theme.border.hex}"

    # Temperature graph colors
    theme[temp_start]="#${c theme.green.hex}"
    theme[temp_mid]="#${c theme.yellow.hex}"
    theme[temp_end]="#${c theme.red.hex}"

    # CPU graph colors
    theme[cpu_start]="#${c theme.green.hex}"
    theme[cpu_mid]="#${c theme.yellow.hex}"
    theme[cpu_end]="#${c theme.red.hex}"

    # Mem/Disk free meter
    theme[free_start]="#${c theme.green.hex}"
    theme[free_mid]="#${c theme.yellow.hex}"
    theme[free_end]="#${c theme.red.hex}"

    # Mem/Disk cached meter
    theme[cached_start]="#${c theme.green.hex}"
    theme[cached_mid]="#${c theme.yellow.hex}"
    theme[cached_end]="#${c theme.red.hex}"

    # Mem/Disk available meter
    theme[available_start]="#${c theme.green.hex}"
    theme[available_mid]="#${c theme.yellow.hex}"
    theme[available_end]="#${c theme.red.hex}"

    # Mem/Disk used meter
    theme[used_start]="#${c theme.green.hex}"
    theme[used_mid]="#${c theme.yellow.hex}"
    theme[used_end]="#${c theme.red.hex}"

    # Download graph colors
    theme[download_start]="#${c theme.green.hex}"
    theme[download_mid]="#${c theme.yellow.hex}"
    theme[download_end]="#${c theme.red.hex}"

    # Upload graph colors
    theme[upload_start]="#${c theme.green.hex}"
    theme[upload_mid]="#${c theme.yellow.hex}"
    theme[upload_end]="#${c theme.red.hex}"
  '';
}
