# LibreWolf about:config overrides — source of truth.
#
# LibreWolf ships aggressive privacy defaults (RFP, WebGL disabled,
# prefetch disabled) that hurt usability. This file declares the
# overrides applied via the wrapper's policies.json.
#
# Tuning knobs (cache sizes, connection limits, DNS TTLs) live in
# base/firefox.ncl — this file only covers LibreWolf-specific fixes.
#
# Consumed by: librewolf.nix (exposes as readOnly HM options)
# Applied in:  firefox.nix   (feeds into wrappers settings block)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/noctalia/librewolf.ncl
#   3. Commit .ncl
{
  fingerprinting
    | doc "Override LibreWolf's Resist Fingerprinting (RFP) with granular FPP"
    | {
      resistFingerprinting
        | doc "RFP master switch — spoofs screen res, timers, fonts. Breaks YouTube quality selection on 4K."
        | Bool,
      protection
        | doc "Fingerprinting Protection — granular replacement for RFP"
        | Bool,
      protectionOverrides
        | doc "FPP overrides. Prefix - to exclude. ScreenRect/FrameRect exclusion stops resolution spoofing."
        | String,
    }
    = {
      resistFingerprinting = false,
      protection = true,
      protectionOverrides = "-ScreenRect,-FrameRect",
    },

  webgl
    | doc "WebGL settings (LibreWolf disables by default)"
    | { disabled | doc "Disable WebGL entirely" | Bool }
    = {
      disabled = false,
    },

  acceleration
    | doc "GPU and video acceleration"
    | {
      webrender | doc "Force WebRender compositor (gfx.webrender.all)" | Bool,
      forceLayers | doc "Force layer acceleration (layers.acceleration.force-enabled)" | Bool,
      hardwareVideoDecode | doc "Force HW video decode — VA-API on Linux (media.hardware-video-decoding.force-enabled)" | Bool,
      rddFfmpeg | doc "FFmpeg in RDD process for VA-API (media.rdd-ffmpeg.enabled)" | Bool,
      forceDmabuf | doc "Force dmabuf for Wayland (widget.dmabuf.force-enabled)" | Bool,
      forceX11Egl | doc "Force X11 EGL (gfx.x11-egl.force-enabled)" | Bool,
    }
    = {
      webrender = true,
      forceLayers = true,
      hardwareVideoDecode = true,
      rddFfmpeg = true,
      forceDmabuf = false,
      forceX11Egl = false,
    },

  ui
    | doc "Browser chrome"
    | {
      compactMode | doc "Show compact mode option in customize toolbar" | Bool,
    }
    = {
      compactMode = true,
    },

  newTab
    | doc "New tab page content (LibreWolf shows blank by default)"
    | {
      topSites | doc "Show top sites" | Bool,
      sponsoredTopSites | doc "Show sponsored top sites" | Bool,
      topStories | doc "Show Pocket top stories" | Bool,
    }
    = {
      topSites = false,
      sponsoredTopSites = false,
      topStories = false,
    },

  urlbar
    | doc "Address bar features"
    | {
      calculator | doc "Inline calculator in URL bar" | Bool,
      unitConversion | doc "Inline unit conversion in URL bar" | Bool,
    }
    = {
      calculator = true,
      unitConversion = true,
    },

  onboarding
    | doc "First-run and discovery prompts"
    | {
      welcome | doc "Show about:welcome page" | Bool,
      tour | doc "Show UI tour tooltips" | Bool,
      discovery | doc "Show extension discovery" | Bool,
      addonsPane | doc "Show recommended addons pane" | Bool,
    }
    = {
      welcome = false,
      tour = false,
      discovery = false,
      addonsPane = false,
    },

  cache
    | doc "Caching strategy"
    | {
      memory | doc "Use memory cache" | Bool,
      disk | doc "Use disk cache" | Bool,
    }
    = {
      memory = true,
      disk = false,
    },

  network
    | doc "Network prefetch overrides (LibreWolf disables all prefetching)"
    | {
      predictor | doc "Enable network predictor" | Bool,
      prefetchNext | doc "Prefetch next page on hover" | Bool,
      dnsPrefetch | doc "Prefetch DNS for links on page" | Bool,
    }
    = {
      predictor = true,
      prefetchNext = true,
      dnsPrefetch = true,
    },
}
