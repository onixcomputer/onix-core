{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    ;

  # Theme NCL data from the shared lazy cache in theme-data.nix.
  # Each theme is a separate thunk — only forced when accessed.
  allThemeData = config.theme.allData;
  activeThemeData = allThemeData.${config.theme.active};

  themeNames = builtins.attrNames allThemeData;

  # Package-dependent fields per theme (can't live in NCL)
  themePackages = {
    tokyo-night = {
      gtk.theme = {
        name = "Tokyonight-Dark";
        package = pkgs.tokyonight-gtk-theme;
      };
      gtk.iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
      wallpapers.collection."tokyo-night_nix.png".source = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_nix.png";
        sha256 = "sha256-W5GaKCOiV2S3NuORGrRaoOE2x9X6gUS+wYf7cQkw9CY=";
      };
      wallpapers.collection."tokyo-night_street.jpg".source = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_street.jpg";
        sha256 = "sha256-XlSm8RzGwowJMT/DQBNwfsU4V6QuvP4kvwVm1pzw6SM=";
      };
    };

    onix-dark = {
      gtk.theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      gtk.iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
    };

    onix-light = {
      gtk.theme = {
        name = "Adwaita";
        package = pkgs.gnome-themes-extra;
      };
      gtk.iconTheme = {
        name = "Papirus-Light";
        package = pkgs.papirus-icon-theme;
      };
    };

    everblush = {
      gtk.theme = {
        name = "Adwaita";
        package = pkgs.gnome-themes-extra;
      };
      gtk.iconTheme = {
        name = "Papirus-Light";
        package = pkgs.papirus-icon-theme;
      };
      wallpapers.collection = {
        "everblush_mountain.png".source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_mountain.png";
          sha256 = "sha256-zaQu4syTlxwLnTwfkhz2yXSyYSkUJnozpVqJYbJHZdU=";
        };
        "everblush_circles.png".source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_circles.png";
          sha256 = "sha256-8VrcK4WWsc6hZQBga/FbjQlmLujskneoe3oIs8BZYZk=";
        };
        "everblush_anger.png".source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_anger.png";
          sha256 = "sha256-39LolpURE+b4PEbuyZM/upmwU+RwtoogvDrSpHyMhL0=";
        };
        "everblush_pacman.png".source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/everblush_pacman.png";
          sha256 = "sha256-kaYs0m3qYQU9G3HEBJV5gmGpYL9SnD6eqwNV0nlqHIM=";
        };
        "swampcat.mp4".source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/adeci/wallpapers/main/everblush/swampcat.mp4";
          sha256 = "sha256-+uCCPUYVRFkpt13eMjwITftcaPZLtGpC2g+dWor5Prk=";
        };
      };
    };

    solarized-dark = {
      gtk.theme = {
        name = "NumixSolarizedDarkBlue";
        package = pkgs.numix-solarized-gtk-theme;
      };
      gtk.iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
      wallpapers.collection = {
        "solarized-dark_jellyfish.jpg".source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/adeci/wallpapers/main/solarized-dark/solarized-dark_jellyfish.jpg";
          sha256 = "sha256-vNBIkJj4QLXYgHkWi3FoXhIh65kT7FmCUokhjcBl6WQ=";
        };
        "solarized-dark_city.png".source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/adeci/wallpapers/main/solarized-dark/solarized-dark_city.png";
          sha256 = "sha256-rMDiMc4eyut0dl8ihs7RWn8eMgPbboJ+x4nXDCJl7J0=";
        };
        "solarized-dark_street.jpeg".source = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/adeci/wallpapers/main/solarized-dark/solarized-dark_street.jpeg";
          sha256 = "sha256-8VAZs9AUtuHYL6spS+ZinXTNiQuF9puwBmAD3Ze+z40=";
        };
      };
    };
  };

  # Merged theme: NCL data + package fields
  pkgData = themePackages.${config.theme.active} or { };
  preferDark = activeThemeData.gtk.prefer_dark_theme or true;

  # Build the merged wallpaper collection
  mergedWallpapers =
    let
      nclCollection = activeThemeData.wallpapers.collection or { };
      pkgCollection = (pkgData.wallpapers or { }).collection or { };
    in
    lib.mapAttrs (name: nclData: nclData // (pkgCollection.${name} or { })) nclCollection;
in
{
  # Options are declared in brittonr/base/theme-data.nix (available to all profiles).
  # This module enriches theme.data with package-dependent fields for desktop.

  config = {
    # Populate theme.data with merged NCL + package data
    theme.data = activeThemeData // {
      gtk = (activeThemeData.gtk or { }) // (pkgData.gtk or { });
      wallpapers = (activeThemeData.wallpapers or { }) // {
        collection = mergedWallpapers;
      };
    };

    home = {
      # Symlink wallpapers from all themes
      file =
        let
          allWallpapers = lib.foldl' (
            acc: themeName:
            let
              themeData = allThemeData.${themeName};
              pkgs' = themePackages.${themeName} or { };
            in
            if themeData ? wallpapers && themeData.wallpapers ? collection then
              acc
              // lib.mapAttrs (
                name: nclData:
                let
                  source = ((pkgs'.wallpapers or { }).collection or { }).${name}.source or null;
                in
                if source != null then
                  { inherit source; }
                else if nclData ? url then
                  {
                    source = pkgs.fetchurl {
                      inherit (nclData) url sha256;
                    };
                  }
                else
                  { }
              ) themeData.wallpapers.collection
            else
              acc
          ) { } themeNames;
        in
        lib.mapAttrs' (
          name: wallpaperConfig:
          lib.nameValuePair "Pictures/Wallpapers/${name}" {
            inherit (wallpaperConfig) source;
          }
        ) (lib.filterAttrs (_: v: v ? source) allWallpapers);

      activation.setThemeWallpaper = lib.hm.dag.entryAfter [ "linkGeneration" ] (
        mkIf (config.theme.autoSetMatchingWallpaper && activeThemeData ? wallpapers) ''
          STATE_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-state"
          mkdir -p "$(dirname "$STATE_FILE")"

          ${
            if activeThemeData.wallpapers.main == "wl-walls" then
              # wl-walls animated wallpaper — managed by noctalia plugin autoStart.
              # Write sentinel so restore-wallpaper knows not to set a static image.
              ''
                echo "wl-walls" > "$STATE_FILE"
              ''
            else
              ''
                WALLPAPER="$HOME/Pictures/Wallpapers/${activeThemeData.wallpapers.main}"
                if [[ -e "$WALLPAPER" ]]; then
                  echo "$WALLPAPER" > "$STATE_FILE"
                  ${pkgs.systemd}/bin/systemctl --user restart apply-theme-wallpaper.service || true
                fi
              ''
          }
        ''
      );

      sessionVariables.GTK_THEME = (pkgData.gtk.theme or { }).name or "Adwaita-dark";
    };

    systemd.user.services.apply-theme-wallpaper = mkIf config.theme.autoSetMatchingWallpaper {
      Unit = {
        Description = "Apply theme wallpaper";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStart = "${pkgs.bash}/bin/bash -c 'PATH=$HOME/.nix-profile/bin:$PATH restore-wallpaper'";
      };
    };

    gtk = {
      enable = true;
      theme =
        pkgData.gtk.theme or {
          name = "Adwaita-dark";
          package = pkgs.gnome-themes-extra;
        };
      iconTheme =
        pkgData.gtk.iconTheme or {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
      gtk3.extraConfig.gtk-application-prefer-dark-theme = preferDark;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = preferDark;
    };

    dconf = {
      enable = true;
      settings."org/gnome/desktop/interface" = {
        color-scheme = if preferDark then "prefer-dark" else "default";
        gtk-theme = (pkgData.gtk.theme or { }).name or "Adwaita-dark";
        icon-theme = (pkgData.gtk.iconTheme or { }).name or "Papirus-Dark";
      };
    };

    qt = {
      enable = true;
      platformTheme.name = "gtk";
      style.name = if preferDark then "adwaita-dark" else "adwaita";
    };
  };
}
