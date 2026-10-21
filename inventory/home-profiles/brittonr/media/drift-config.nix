{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  inherit (config) mpdConfig;
  remote = osConfig.services.drift-rustfs or { };
  storageOverrides = lib.optionalAttrs (remote.enable or false) remote.clientConfig;

  # TOML generation — nix attrs → drift config.toml
  driftConfig = {
    mpd = {
      host = "localhost";
      inherit (mpdConfig) port;
    };

    playback = {
      default_volume = 80;
      audio_quality = "lossless";
      resume_on_startup = true;
    };

    ui = {
      show_visualizer = true;
      show_album_art = true;
      visualizer_bars = 20;
      status_interval_ms = 200;
      album_art_cache_size = 50;
    };

    downloads = {
      max_concurrent = 2;
      auto_tag = true;
      sync_interval_minutes = 30;
    };

    service = {
      primary = "tidal";
      auto_detect = true;
    };

    search = {
      max_results = 30;
      debounce_ms = 300;
      fuzzy_filter = true;
      timeout_seconds = 10;
      history_size = 50;
      live_preview = true;
      min_chars = 2;
      cache_enabled = true;
      cache_ttl_seconds = 3600;
    };

    video = {
      fullscreen = false;
      hwdec = "auto";
    };

    storage = {
      backend = "local";
      sync_enabled = false;
      prefer_local_files = true;
      metadata_cache_ttl_minutes = 60;
      wal_max_entries = 1000;
      wal_max_age_days = 7;
    }
    // storageOverrides;
  };

  configToml = (pkgs.formats.toml { }).generate "drift-config.toml" driftConfig;
in
{
  xdg.configFile."drift/config.toml" = {
    source = configToml;
  };
}
