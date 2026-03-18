{ config, lib, ... }:
let
  inherit (config) mpdConfig;

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
    };
  };

  # Convert nix attrs to TOML format
  tomlValue =
    v:
    if builtins.isBool v then
      (if v then "true" else "false")
    else if builtins.isInt v then
      toString v
    else if builtins.isString v then
      ''"${v}"''
    else
      toString v;

  tomlSection =
    name: attrs:
    "[${name}]\n"
    + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (k: v: "${k} = ${tomlValue v}") attrs
    );

  configToml = lib.concatStringsSep "\n\n" (
    lib.mapAttrsToList tomlSection driftConfig
  );
in
{
  xdg.configFile."drift/config.toml" = {
    text = configToml;
  };
}
