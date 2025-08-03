_: {
  programs.element-desktop = {
    enable = true;
  };

  xdg.desktopEntries.element-desktop = {
    name = "Element";
    exec = "element-desktop --password-store=gnome-libsecret %u";
    icon = "element";
    type = "Application";
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
  };
}
