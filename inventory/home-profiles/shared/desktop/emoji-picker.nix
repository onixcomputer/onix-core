{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bemoji # Emoji picker for Wayland
    wtype # Type emoji into focused window
    fuzzel # Picker UI (bemoji auto-detects on Wayland)
  ];
}
