# Theme module - provides a clean interface for color theming
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  themes = {
    tokyo-night = import ./themes/tokyo-night.nix { inherit pkgs; };
    everblush = import ./themes/everblush.nix { inherit pkgs; };
    solarized-dark = import ./themes/solarized-dark.nix { inherit pkgs; };
  };
in
{
  options.theme = {
    active = mkOption {
      type = types.enum (attrNames themes);
      default = "tokyo-night";
      description = "The active theme name";
      example = "tokyo-night";
    };

    autoSetMatchingWallpaper = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically set matching wallpaper when theme changes";
    };

    colors = mkOption {
      type = types.attrs;
      readOnly = true;
      description = "The active theme's color palette";
    };
  };

  config = {
    theme.colors = themes.${config.theme.active};

    # Combine all home configuration
    home = {
      # Symlink ALL wallpapers from ALL themes to ~/Pictures/Wallpapers
      file =
        let
          # Collect all wallpapers from all themes
          allWallpapers = lib.foldl' (
            acc: themeName:
            let
              theme = themes.${themeName};
            in
            if theme ? wallpapers then acc // theme.wallpapers.collection else acc
          ) { } (attrNames themes);
        in
        lib.mapAttrs' (
          name: wallpaperConfig:
          lib.nameValuePair "Pictures/Wallpapers/${name}" {
            source = pkgs.fetchurl {
              inherit (wallpaperConfig) url sha256;
            };
          }
        ) allWallpapers;

      # Update wallpaper state file when theme changes
      # The actual wallpaper application happens via restore-wallpaper on Hyprland start
      activation.setThemeWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        mkIf (config.theme.autoSetMatchingWallpaper && config.theme.colors ? wallpapers) ''
          # Simply update the state file that restore-wallpaper uses
          WALLPAPER="$HOME/Pictures/Wallpapers/${config.theme.colors.wallpapers.main}"
          STATE_FILE="$HOME/.cache/wallpaper-state"

          if [[ -e "$WALLPAPER" ]]; then
            mkdir -p "$(dirname "$STATE_FILE")"
            echo "$WALLPAPER" > "$STATE_FILE"
          fi
        ''
      );

      # Session variables
      sessionVariables.GTK_THEME = config.theme.colors.gtk.theme.name;
    };

    # Systemd user service to apply wallpaper after theme change
    systemd.user.services.apply-theme-wallpaper = mkIf config.theme.autoSetMatchingWallpaper {
      Unit = {
        Description = "Apply theme wallpaper";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "apply-theme-wallpaper" ''
          #!/usr/bin/env bash
          # Wait a moment for the environment to be ready
          sleep 1

          # Use restore-wallpaper which handles all the logic
          if command -v restore-wallpaper >/dev/null 2>&1; then
            restore-wallpaper
          fi
        ''}";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Apply GTK theme from the active theme
    gtk = {
      enable = true;
      inherit (config.theme.colors.gtk) theme iconTheme;
      gtk3.extraConfig.gtk-application-prefer-dark-theme = config.theme.colors.gtk.preferDarkTheme;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = config.theme.colors.gtk.preferDarkTheme;
    };

    # dconf settings for GNOME/GTK apps
    # FIXME: Commenting out dconf to avoid 26s hang during switches
    # dconf = {
    #   enable = true;
    #   settings."org/gnome/desktop/interface" = {
    #     color-scheme = if config.theme.colors.gtk.preferDarkTheme then "prefer-dark" else "default";
    #     gtk-theme = config.theme.colors.gtk.theme.name;
    #     icon-theme = config.theme.colors.gtk.iconTheme.name;
    #   };
    # };

    # Qt theme configuration to match GTK
    qt = {
      enable = true;
      platformTheme.name = "gtk";
      style.name = if config.theme.colors.gtk.preferDarkTheme then "adwaita-dark" else "adwaita";
    };
  };
}
