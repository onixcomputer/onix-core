{
  inputs,
  pkgs,
  config,
  ...
}:
let
  tridactyl = pkgs.fetchFirefoxAddon {
    name = "tridactyl";
    url = "https://addons.mozilla.org/firefox/downloads/file/4549492/tridactyl_vim-1.24.4.xpi";
    hash = "sha256:9ba7d6bc3be555631c981c3acdd25cab6942c1f4a6f0cb511bbe8fa81d79dd9d";
    fixedExtid = "tridactyl.vim@cmcaine.co.uk";
  };

  ublock-origin = pkgs.fetchFirefoxAddon {
    name = "ublock-origin";
    url = "https://addons.mozilla.org/firefox/downloads/file/4675310/ublock_origin-1.69.0.xpi";
    hash = "sha256:785bcde68a25faa8a0949964ec5ffe9bdcb85d3f0ae21c23f607c6c8f91472cf";
    fixedExtid = "uBlock0@raymondhill.net";
  };

  bitwarden = pkgs.fetchFirefoxAddon {
    name = "bitwarden";
    url = "https://addons.mozilla.org/firefox/downloads/file/4664623/bitwarden_password_manager-2025.12.1.xpi";
    hash = "sha256:a7a123eee4e40fdd8af7c0c67243731ddcc37ae1498cf2828995f4905600c51f";
    fixedExtid = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
  };

  k = config.keymap;

  wrappedFirefox =
    (inputs.wrappers.wrapperModules.firefox.apply {
      inherit pkgs;

      extensions = [
        tridactyl
        ublock-origin
        bitwarden
      ];

      nativeMessagingHosts = [ pkgs.tridactyl-native ];

      settings = {
        # Hardware acceleration - WebRender
        "gfx.webrender.all" = true;
        "layers.acceleration.force-enabled" = true;

        # VA-API hardware video decoding (Firefox 137+)
        "media.hardware-video-decoding.force-enabled" = true;
        "media.rdd-ffmpeg.enabled" = true;

        # Wayland-native settings
        "widget.dmabuf.force-enabled" = false;
        "gfx.x11-egl.force-enabled" = false;

        # Compact UI
        "browser.compactmode.show" = true;
        "browser.uidensity" = config.firefox.ui.density;

        # Disable new-tab-page noise
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;

        # Auto-close cookie banners
        "cookiebanners.service.mode" = config.firefox.privacy.cookieBannerMode;
        "cookiebanners.service.mode.privateBrowsing" = config.firefox.privacy.cookieBannerMode;

        # URL bar calculator and unit conversion
        "browser.urlbar.suggest.calculator" = true;
        "browser.urlbar.unitConversion.enabled" = true;

        # Disable Firefox welcome/tour/discovery
        "browser.aboutwelcome.enabled" = false;
        "browser.uitour.enabled" = false;
        "browser.discovery.enabled" = false;
        "extensions.getAddons.showPane" = false;

        # Canvas acceleration cache
        "gfx.canvas.accelerated.cache-items" = config.firefox.cache.canvasItems;
        "gfx.canvas.accelerated.cache-size" = config.firefox.cache.canvasSize;

        # DNS cache tuning
        "network.dnsCacheEntries" = config.firefox.dns.cacheEntries;
        "network.dnsCacheExpiration" = config.firefox.dns.cacheExpiration;

        # Network connection limits
        "network.http.max-connections" = config.firefox.network.maxConnections;
        "network.http.max-persistent-connections-per-server" =
          config.firefox.network.maxPersistentPerServer;
        "network.http.max-urgent-start-excessive-connections-per-host" =
          config.firefox.network.maxUrgentStartExcessivePerHost;

        # Speculative/predictive loading
        "network.http.speculative-parallel-limit" = config.firefox.network.speculativeParallelLimit;
        "network.predictor.enabled" = true;
        "network.prefetch-next" = true;
        "network.dns.disablePrefetch" = false;

        # Memory cache (disable disk cache, use memory)
        "browser.cache.memory.enable" = true;
        "browser.cache.disk.enable" = false;
      };

      extraPolicies = {
        SearchEngines = {
          Default = "Kagi";
          Add = [
            {
              Name = "Kagi";
              URLTemplate = "https://kagi.com/search?q={searchTerms}";
              Method = "GET";
              IconURL = "https://assets.kagi.com/v2/favicon-32x32.png";
              Description = "Kagi Search";
            }
          ];
          Remove = [
            "Google"
            "Bing"
            "Amazon.com"
            "DuckDuckGo"
            "Wikipedia (en)"
          ];
        };
      };
    }).wrapper;
in
{
  home.packages = [ wrappedFirefox ];

  xdg = {
    # Set LibreWolf as the default browser for all web MIME types
    mimeApps.enable = true;
    mimeApps.defaultApplications = {
      "x-scheme-handler/http" = [ "librewolf.desktop" ];
      "x-scheme-handler/https" = [ "librewolf.desktop" ];
      "text/html" = [ "librewolf.desktop" ];
      "application/xhtml+xml" = [ "librewolf.desktop" ];
    };

    # Prevent mimeapps.list backup conflict during home-manager activation
    configFile."mimeapps.list".force = true;

    configFile."tridactyl/tridactylrc".text = ''
      " Reset to defaults
      sanitise tridactyllocal tridactylsync

      " --- Visual mode (Helix-like select-then-act) ---
      " v enters visual, hjkl/w/b/e extend selection, y yanks, o swaps cursor end
      " These are built-in defaults that match Helix already.
      " Extend with Helix-style binds:
      bind --mode=visual x js document.getSelection().modify("extend","forward","line")
      bind --mode=visual d composite js document.getSelection().toString() | clipboard yank | js document.getSelection().empty()

      " --- Helix-inspired goto (g prefix) ---
      bind ${k.goto.prefix}${k.goto.bottom} scrollto 100
      bind ${k.goto.prefix}${k.goto.top} scrollto 0
      bind ${k.goto.prefix}${k.goto.nextTab} tabnext
      bind ${k.goto.prefix}${k.goto.prevTab} tabprev

      " --- Space leader (matching user's Helix config) ---
      bind <Space><Space> fillcmdline tabopen
      bind <Space>${k.leaderActions.search} fillcmdline find
      bind <Space>${k.leaderActions.bufferPicker} fillcmdline buffer
      bind <Space>${k.leaderActions.close} tabclose

      " --- Tab navigation ---
      bind ${k.tabs.prev} tabprev
      bind ${k.tabs.next} tabnext

      " --- General settings ---
      set smoothscroll true
      set hintchars ${k.hintChars}
    '';
  };
}
