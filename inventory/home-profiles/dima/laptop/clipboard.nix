{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Clipboard utilities
    wl-clipboard
    wl-clip-persist
    cliphist
  ];
}
