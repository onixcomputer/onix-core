{ config, pkgs, ... }:
let
  theme = config.theme.colors;
in
{
  programs.wofi = {
    enable = true;

    settings = {
      width = 600;
      height = 500;
      location = "center";
      show = "drun";
      prompt = "Apps";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 40;
      gtk_dark = true;
    };

    style = ''
      * {
        font-family: "CaskaydiaMono Nerd Font";
        color: ${theme.fg};
      }

      window {
        border: 3px solid ${theme.accent};
        background: ${theme.bg};
        border-radius: 15px;
      }

      #input {
        margin: 1.5em;
        margin-bottom: 0em;
        padding: 1em;
        border: none;
        font-weight: bold;
        background: ${theme.bg};
        color: ${theme.fg};
        border-radius: 15px;
      }

      #input:focus {
        border: 1px solid ${theme.accent};
      }

      #inner-box {
        margin: 1.5em;
        margin-top: 0.5em;
      }

      #outer-box {
        margin-bottom: 0.5em;
      }

      #scroll {
        margin-top: 5px;
      }

      #text {
        margin-left: 0.5em;
        color: ${theme.fg};
      }

      #text:selected {
        color: ${theme.bg_dark};
      }

      #entry {
        margin-top: 0.5em;
        border-radius: 15px;
      }

      #entry:selected {
        background: linear-gradient(90deg, ${theme.accent} 0%, ${theme.accent2} 80%);
      }
    '';
  };

  home.packages = with pkgs; [
    (writeShellScriptBin "wofi-emoji" ''
      ${wofi}/bin/wofi -d -i --show dmenu | wl-copy
    '')

    (writeShellScriptBin "wofi-power" ''
      entries="⇠ Logout\n⭮ Reboot\n⏻ Shutdown"

      selected=$(echo -e $entries | ${wofi}/bin/wofi --width 250 --height 150 --dmenu --cache-file /dev/null | ${gawk}/bin/awk '{print tolower($2)}')

      case $selected in
        logout)
          ${pkgs.hyprland}/bin/hyprctl dispatch exit;;
        reboot)
          exec ${pkgs.systemd}/bin/systemctl reboot;;
        shutdown)
          exec ${pkgs.systemd}/bin/systemctl poweroff -i;;
      esac
    '')
  ];
}
