{ pkgs, ... }:
{
  # Install wlogout package
  home.packages = with pkgs; [
    wlogout
  ];

  # wlogout configuration - 4 button layout like the inspiration config
  xdg.configFile."wlogout/layout".text = ''
    {
      "label": "lock",
      "action": "hyprlock",
      "keybind": "l"
    }
    {
      "label": "reboot",
      "action": "systemctl reboot",
      "keybind": "r"
    }
    {
      "label": "logout",
      "action": "hyprctl dispatch exit",
      "keybind": "e"
    }
    {
      "label": "shutdown",
      "action": "systemctl poweroff",
      "keybind": "s"
    }
  '';

  # wlogout styling - Matching the inspiration config's clean 2x2 grid
  xdg.configFile."wlogout/style.css".text = ''
    * {
      box-shadow: none;
    }

    window {
      background-color: rgba(0, 0, 0, 0.75);
    }

    button {
      color: #FFFFFF;
      opacity: 0.5;
      background-position: center;
      background-size: 25%;
      background-repeat: no-repeat;
      box-shadow: none;
      border: 3px solid transparent;
      min-width: 0;
      min-height: 0;
    }

    button:focus,
    button:active {
      background-color: rgba(90, 90, 90, 0.8);
      opacity: 1;
      outline-style: none;
    }

    button:hover {
      background-color: rgba(90, 90, 90, 0.4);
      opacity: 0.8;
      outline-style: none;
    }

    /* 2x2 grid with proper sizing */
    #lock {
      background-color: #7aa2f7;
      background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
      border-radius: 20px 0px 0px 0px;
      margin: 10px 5px 5px 10px;
    }

    #reboot {
      background-color: #9ece6a;
      background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
      border-radius: 0px 0px 0px 20px;
      margin: 5px 5px 10px 10px;
    }

    #logout {
      background-color: #bb9af7;
      background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
      border-radius: 0px 20px 0px 0px;
      margin: 10px 10px 5px 5px;
    }

    #shutdown {
      background-color: #f7768e;
      background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
      border-radius: 0px 0px 20px 0px;
      margin: 5px 10px 10px 5px;
    }
  '';
}
