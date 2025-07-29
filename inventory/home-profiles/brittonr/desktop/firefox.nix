{ inputs, pkgs, ... }:
{
  programs.firefox = {
    enable = true;

    profiles.britton = {
      id = 0;
      isDefault = true;

      extensions.packages = with inputs.firefox-addons.packages.${pkgs.system}; [
        ublock-origin
        adblocker-ultimate
        darkreader
        return-youtube-dislikes
        youtube-nonstop
        youtube-shorts-block
      ];

      settings = {
        "sidebar.revamp" = true;
        "sidebar.verticalTabs" = true;
        "browser.toolbars.bookmarks.visibility" = "never";

        # Performance settings for Linux video playback
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;
      };
    };

    policies = {
      # unfree extensions
      ExtensionSettings = {
        "firefox@betterttv.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/betterttv/latest.xpi";
        };
      };
    };
  };
}
