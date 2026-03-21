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

  alby = pkgs.fetchFirefoxAddon {
    name = "alby";
    url = "https://addons.mozilla.org/firefox/downloads/file/4668366/alby-3.14.1.xpi";
    hash = "sha256:a9be04bd7b9dba189e808f14a3766aaebdc27b920e27e838497ca073289d5a87";
    fixedExtid = "extension@getalby.com";
  };

  k = config.keymap;
  lw = config.librewolf;
  ff = config.firefox;

  wrappedFirefox =
    (inputs.wrappers.wrapperModules.firefox.apply {
      inherit pkgs;

      extensions = [
        tridactyl
        ublock-origin
        bitwarden
        alby
      ];

      nativeMessagingHosts = [ pkgs.tridactyl-native ];

      settings = {
        # --- LibreWolf overrides (source: librewolf.ncl) ---

        # Fingerprinting
        "privacy.resistFingerprinting" = lw.fingerprinting.resistFingerprinting;
        "privacy.fingerprintingProtection" = lw.fingerprinting.protection;
        "privacy.fingerprintingProtection.overrides" = lw.fingerprinting.protectionOverrides;

        # WebGL
        "webgl.disabled" = lw.webgl.disabled;

        # GPU / video acceleration
        "gfx.webrender.all" = lw.acceleration.webrender;
        "layers.acceleration.force-enabled" = lw.acceleration.forceLayers;
        "media.hardware-video-decoding.force-enabled" = lw.acceleration.hardwareVideoDecode;
        "media.rdd-ffmpeg.enabled" = lw.acceleration.rddFfmpeg;
        "widget.dmabuf.force-enabled" = lw.acceleration.forceDmabuf;
        "gfx.x11-egl.force-enabled" = lw.acceleration.forceX11Egl;

        # UI chrome
        "browser.compactmode.show" = lw.ui.compactMode;
        "browser.uidensity" = ff.ui.density;

        # New tab page
        "browser.newtabpage.activity-stream.feeds.topsites" = lw.newTab.topSites;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = lw.newTab.sponsoredTopSites;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = lw.newTab.topStories;

        # Cookie banners (source: base/firefox.ncl)
        "cookiebanners.service.mode" = ff.privacy.cookieBannerMode;
        "cookiebanners.service.mode.privateBrowsing" = ff.privacy.cookieBannerMode;

        # URL bar
        "browser.urlbar.suggest.calculator" = lw.urlbar.calculator;
        "browser.urlbar.unitConversion.enabled" = lw.urlbar.unitConversion;

        # Onboarding
        "browser.aboutwelcome.enabled" = lw.onboarding.welcome;
        "browser.uitour.enabled" = lw.onboarding.tour;
        "browser.discovery.enabled" = lw.onboarding.discovery;
        "extensions.getAddons.showPane" = lw.onboarding.addonsPane;

        # Canvas acceleration cache (source: base/firefox.ncl)
        "gfx.canvas.accelerated.cache-items" = ff.cache.canvasItems;
        "gfx.canvas.accelerated.cache-size" = ff.cache.canvasSize;

        # DNS cache (source: base/firefox.ncl)
        "network.dnsCacheEntries" = ff.dns.cacheEntries;
        "network.dnsCacheExpiration" = ff.dns.cacheExpiration;

        # Connection limits (source: base/firefox.ncl)
        "network.http.max-connections" = ff.network.maxConnections;
        "network.http.max-persistent-connections-per-server" = ff.network.maxPersistentPerServer;
        "network.http.max-urgent-start-excessive-connections-per-host" =
          ff.network.maxUrgentStartExcessivePerHost;
        "network.http.speculative-parallel-limit" = ff.network.speculativeParallelLimit;

        # Network prefetch overrides (source: librewolf.ncl)
        "network.predictor.enabled" = lw.network.predictor;
        "network.prefetch-next" = lw.network.prefetchNext;
        "network.dns.disablePrefetch" = !lw.network.dnsPrefetch;

        # Cache strategy (source: librewolf.ncl)
        "browser.cache.memory.enable" = lw.cache.memory;
        "browser.cache.disk.enable" = lw.cache.disk;
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
    # MIME associations for web types are in xdg.ncl

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
