# User settings — source of truth for all data-only options.
#
# Consolidates location, locale, paths, accessibility, workspaces,
# timing, opacity, monitors, terminal, font, layout, icons, animations,
# wallpaper, color-scheme, and media-paths into a single validated file.
#
# Consumed by: settings.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/settings.ncl
#   3. Commit .ncl
let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

let Positive =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

let UnitInterval =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 && value <= 1 => 'Ok,
    _ => 'Error { message = "must be between 0 and 1" },
  }
  )
in

let HexAlpha =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value == 2 => 'Ok,
    _ => 'Error { message = "must be a 2-char hex string" },
  }
  )
in

{
  location | { lat | Number, lng | Number } = {
    lat = 52.3,
    lng = 4.8,
  },

  locale
    | {
      timezone | NonEmpty,
      language | NonEmpty,
      clockFormat | NonEmpty,
      dateFormat | NonEmpty,
      timeFormat | NonEmpty,
      units | NonEmpty,
    }
    = {
      timezone = "Europe/Amsterdam",
      language = "en_US.UTF-8",
      clockFormat = "{:%Y-%m-%d %H:%M}",
      dateFormat = "%Y-%m-%d",
      timeFormat = "%H:%M",
      units = "metric",
    },

  paths
    | {
      screenshots | NonEmpty,
      wallpapers | NonEmpty,
      downloads | NonEmpty,
      wallpapersRepo | NonEmpty,
      defaultWallpaper | NonEmpty,
    }
    = {
      screenshots = "~/Pictures/Screenshots",
      wallpapers = "~/Pictures/Wallpapers",
      downloads = "~/Downloads",
      wallpapersRepo = "~/git/wallpapers",
      defaultWallpaper = "~/git/wallpapers/1-matte-black.jpg",
    },

  mediaPaths
    | {
      musicDirectory | NonEmpty,
      playlistDirectory | NonEmpty,
      stateDirectory | NonEmpty,
      fifoPath | NonEmpty,
    }
    = {
      musicDirectory = "/srv/music",
      playlistDirectory = "/srv/music/playlists",
      stateDirectory = "/var/lib/mpd",
      fifoPath = "/tmp/mpd.fifo",
    },

  accessibility
    | {
      dpi | Positive,
      fontScale | Positive,
      keyboard | { repeatDelay | Positive, repeatRate | Positive },
      highContrast | Bool,
    }
    = {
      dpi = 96,
      fontScale = 1.0,
      keyboard = {
        repeatDelay = 250,
        repeatRate = 30,
      },
      highContrast = false,
    },

  workspaces | { count | Positive, names | Array NonEmpty } = {
    count = 10,
    names = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
  },

  timing
    | {
      process | { veryShort | NonEmpty, short | NonEmpty, daemonStart | NonEmpty, wifiScan | NonEmpty },
      polling | { fast | Positive, normal | Positive, slow | Positive },
      notification | { gesture | Positive, quick | Positive, standard | Positive, long | Positive },
    }
    = {
      process = {
        veryShort = "0.2",
        short = "0.5",
        daemonStart = "1",
        wifiScan = "2",
      },
      polling = {
        fast = 1,
        normal = 2,
        slow = 5,
      },
      notification = {
        gesture = 400,
        quick = 1000,
        standard = 2000,
        long = 10000,
      },
    },

  opacity
    | {
      terminal | UnitInterval,
      bars | UnitInterval,
      panels | UnitInterval,
      inactive | UnitInterval,
      swayosd | UnitInterval,
      hex | { opaque | HexAlpha, high | HexAlpha, medium | HexAlpha, low | HexAlpha, subtle | HexAlpha },
      blur | { size | Positive, passes | Positive, vibrancy | UnitInterval, noise | UnitInterval },
    }
    = {
      terminal = 0.92,
      bars = 0.95,
      panels = 0.85,
      inactive = 0.9,
      swayosd = 0.97,
      hex = {
        opaque = "ff",
        high = "ee",
        medium = "aa",
        low = "70",
        subtle = "40",
      },
      blur = {
        size = 8,
        passes = 2,
        vibrancy = 0.2,
        noise = 0.02,
      },
    },

  monitors = {
    primary
      | {
        name | NonEmpty,
        mode | NonEmpty,
        scale | Positive,
        position | { x | Number, y | Number },
        vrr | Bool,
      }
      = {
        name = "DP-3",
        mode = "3840x2160@240.084",
        scale = 1.5,
        position = { x = 0, y = 0 },
        vrr = true,
      },
    secondary
      | {
        name | NonEmpty,
        mode | NonEmpty,
        scale | Positive,
        position | { x | Number, y | Number },
        vrr | Bool,
      }
      = {
        name = "HDMI-A-2",
        mode = "2880x1800@99.999",
        scale = 1.2,
        position = { x = 960, y = 2160 },
        vrr = false,
      },
    builtin | { name | NonEmpty } = {
      name = "eDP-1",
    },
  },

  terminal
    | {
      cursorBlinkInterval | NonEmpty,
      cursorTrail | Number,
      cursorStopBlinkingAfter | Number,
      repaintDelay | Positive,
      inputDelay | Positive,
      visualBellDuration | Number,
      updateCheckInterval | Number,
      scrollbackLines | Positive,
      mouseHideWait | Positive,
      minimumContrast | Positive,
      inactiveTextAlpha | UnitInterval,
      textComposition | { gamma | Positive, scale | Positive },
      scrollbar
        | {
          width | Positive,
          hoverWidth | Positive,
          radius | Number,
          gap | Number,
          minHandleHeight | Positive,
          handleOpacity | UnitInterval,
          trackOpacity | UnitInterval,
        },
    }
    = {
      cursorBlinkInterval = "0.5",
      cursorTrail = 3,
      cursorStopBlinkingAfter = 0,
      repaintDelay = 10,
      inputDelay = 3,
      visualBellDuration = 0,
      updateCheckInterval = 0,
      scrollbackLines = 10000,
      mouseHideWait = 3,
      minimumContrast = 7.0,
      inactiveTextAlpha = 0.8,
      textComposition = {
        gamma = 1.0,
        scale = 1.75,
      },
      scrollbar = {
        width = 1,
        hoverWidth = 2,
        radius = 0.5,
        gap = 0.1,
        minHandleHeight = 2,
        handleOpacity = 0.6,
        trackOpacity = 0.1,
      },
    },

  font = {
    mono | NonEmpty = "CaskaydiaMono Nerd Font",
    ui | NonEmpty = "CaskaydiaMono Nerd Font",
    size
      | {
        terminal | Positive,
        notification | Positive,
        bar | Positive,
        small | Positive,
      }
      = {
        terminal = 12,
        notification = 11,
        bar = 13,
        small = 11,
      },
    stacks = {
      sans | Array NonEmpty = ["Noto Sans", "Liberation Sans", "DejaVu Sans"],
      serif | Array NonEmpty = ["Noto Serif", "Liberation Serif", "DejaVu Serif"],
      monospace | Array String = [
        "CaskaydiaMono Nerd Font",
        "Berkeley Mono",
        "Liberation Mono",
        "DejaVu Sans Mono",
      ],
      emoji | Array NonEmpty = ["Noto Color Emoji"],
      cjk | Array NonEmpty = ["Noto Sans CJK"],
      subtitle | NonEmpty = "Liberation Sans",
    },
  },

  layout = {
    borderWidth | Number = 2,
    borderRadius | Number = 0,
    gaps | Number = 4,
    focusRingWidth | Number = 1,
    presetColumnWidths | Array Number = [0.33333, 0.5, 0.66667],
    resizePercent | Positive = 10,
    terminal | { padding | Number } = {
      padding = 14,
    },
  },

  icons = {
    media = {
      default | String = "",
      spotify | String = "",
      librewolf | String = "",
      chromium | String = "",
      mpv | String = "",
    },
    system = {
      cpu | NonEmpty = "󰍛",
      memory | NonEmpty = "󰘚",
      temperature | NonEmpty = "󰔏",
      temperatureCritical | NonEmpty = "󰸁",
    },
    battery = {
      charging | NonEmpty = "󰂄",
      plugged | NonEmpty = "󰚥",
      levels | Array NonEmpty = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"],
    },
    audio = {
      muted | NonEmpty = "󰝟",
      levels | Array NonEmpty = ["󰕿", "󰖀", "󰕾"],
    },
    network = {
      wifi | NonEmpty = "󰤨",
      wifiSwitch | NonEmpty = "󰖩",
      ethernet | NonEmpty = "󰈁",
      settings | NonEmpty = "󰢾",
      rescan | NonEmpty = "󰛵",
      lock | NonEmpty = "󰌾",
    },
    workspace = {
      active | NonEmpty = "●",
      default | String = "",
    },
    apps = {
      terminal | String = "",
      launcher | String = "",
      nixos | String = "",
    },
    generations = {
      current | String = "",
      other | String = "",
      rebuild | String = "",
      garbage | String = "",
      list | String = "",
    },
  },

  animations = {
    beziers = {
      easeOutQuint | NonEmpty = "0.23,1,0.32,1",
      easeInOutCubic | NonEmpty = "0.65,0.05,0.36,1",
      linear | NonEmpty = "0,0,1,1",
      almostLinear | NonEmpty = "0.5,0.5,0.75,1.0",
      quick | NonEmpty = "0.15,0,0.1,1",
      easeOutBack | NonEmpty = "0.34,1.3,0.64,1",
      easeInBack | NonEmpty = "0.36,0,0.66,-0.3",
    },
    hyprBeziers | Array String = [
      "easeOutQuint,0.23,1,0.32,1",
      "easeInOutCubic,0.65,0.05,0.36,1",
      "linear,0,0,1,1",
      "almostLinear,0.5,0.5,0.75,1.0",
      "quick,0.15,0,0.1,1",
      "easeOutBack,0.34,1.3,0.64,1",
      "easeInBack,0.36,0,0.66,-0.3",
    ],
    hyprAnimations | Array String = [
      "global, 1, 10, default",
      "border, 1, 5.39, easeOutQuint",
      "windows, 1, 4.79, easeOutQuint",
      "windowsIn, 1, 4.1, easeOutQuint, popin 87%",
      "windowsOut, 1, 1.49, linear, popin 87%",
      "fadeIn, 1, 1.73, almostLinear",
      "fadeOut, 1, 1.46, almostLinear",
      "fade, 1, 3.03, quick",
      "layers, 1, 3.81, easeOutQuint",
      "layersIn, 1, 4, easeOutQuint, fade",
      "layersOut, 1, 1.5, linear, fade",
      "fadeLayersIn, 1, 1.79, almostLinear",
      "fadeLayersOut, 1, 1.39, almostLinear",
      "workspaces, 0, 0, default",
    ],
  },

  wallpaper
    | {
      fillColor | NonEmpty,
      fillMode | NonEmpty,
      automationEnabled | Bool,
      changeMode | NonEmpty,
      randomIntervalSec | Positive,
      transitionDuration | Positive,
      transitionType | NonEmpty,
      gif | { transitionType | NonEmpty, transitionDuration | Positive, transitionFps | Positive },
      static
        | {
          transitionType | NonEmpty,
          transitionDuration | Positive,
          transitionFps | Positive,
          transitionStep | Positive,
          transitionPos | NonEmpty,
          transitionBezier | NonEmpty,
        },
    }
    = {
      fillColor = "000000",
      fillMode = "crop",
      automationEnabled = false,
      changeMode = "random",
      randomIntervalSec = 300,
      transitionDuration = 1500,
      transitionType = "random",
      gif = {
        transitionType = "fade",
        transitionDuration = 2,
        transitionFps = 60,
      },
      static = {
        transitionType = "center",
        transitionDuration = 3,
        transitionFps = 60,
        transitionStep = 90,
        transitionPos = "center",
        transitionBezier = ".54,0,.34,.99",
      },
    },

  colorScheme
    | {
      useWallpaperColors | Bool,
      darkMode | Bool,
      schedulingMode | NonEmpty,
      generationMethod | NonEmpty,
    }
    = {
      useWallpaperColors = false,
      darkMode = true,
      schedulingMode = "off",
      generationMethod = "tonal-spot",
    },

  build | { pueue | { parallelTasks | Positive } } = {
    pueue = {
      parallelTasks = 4,
    },
  },
}
