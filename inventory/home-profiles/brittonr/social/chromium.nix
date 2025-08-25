_: {
  programs.chromium = {
    enable = true;
    commandLineArgs = [
      # Use Wayland Ozone platform for proper rendering
      "--enable-features=UseOzonePlatform"
      "--ozone-platform=wayland"

      # Match Hyprland scaling
      "--force-device-scale-factor=1.5"

      # Enable extensions
      "--enable-extensions"
      "--enable-remote-extensions"
    ];
    extensions = [
      { id = "cdglnehniifkbagbbombnjghhcihifij"; } # Kagi Search
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
    ];
  };
}
